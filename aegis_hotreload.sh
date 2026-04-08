#!/bin/bash
# ==============================================================================
# AEGIS OS - HOT-RELOAD SCRIPT (SRE GRADE)
# ==============================================================================
# Ticket: INST-121 | Epic 24 - Dev Sync & Hot-Reload Toolchain
# Runs on: Debian server
# Installs to: /usr/local/bin/aegis_hotreload.sh
# Usage: aegis_hotreload.sh [--repo ank|shell|installer|all] [--force-full]
# ==============================================================================

set -euo pipefail

# --- Configuration ---
COMPOSE_DIR="/opt/aegis/Aegis-Installer"
ANK_SRC_DIR="/opt/aegis/Aegis-ANK"
BFF_HEALTH_URL="http://localhost:8000/api/system/state"
ANK_PORT=50051
ANK_TIMEOUT=500
HEALTH_RETRIES=10
HEALTH_RETRY_DELAY=5

# --- Docker Compose Command Detection ---
get_compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif docker-compose version &>/dev/null; then
        echo "docker-compose"
    else
        echo "docker compose" # Fallback to default
    fi
}
COMPOSE_CMD=$(get_compose_cmd)

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Timing ---
START_TIME=$(date +%s)

# --- Logging ---
log()     { echo -e "[$(date '+%H:%M:%S')] ${CYAN}[INFO]${NC} $1"; }
success() { echo -e "[$(date '+%H:%M:%S')] ${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "[$(date '+%H:%M:%S')] ${YELLOW}[WARN]${NC} $1"; }

error_exit() {
    echo -e "[$(date '+%H:%M:%S')] ${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# --- Argument Parsing ---
REPO="all"
FORCE_FULL=false
RESET_SYSTEM=false

# --- Privilege Wrapper ---
# Detects if sudo is needed for docker/file operations
SUDO_CMD=""
if [[ $EUID -ne 0 ]] && ! groups | grep -qi "docker"; then
    SUDO_CMD="sudo"
fi

# Same for file operations (if not owner, use sudo)
FILE_SUDO=""
[[ $EUID -ne 0 ]] && FILE_SUDO="sudo"

# --- Docker Compose Command Detection ---
get_compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "$SUDO_CMD docker compose"
    elif docker-compose version &>/dev/null; then
        echo "$SUDO_CMD docker-compose"
    else
        echo "$SUDO_CMD docker compose" # Fallback to default
    fi
}
DOCKER_CMD="$SUDO_CMD docker"
COMPOSE_CMD=$(get_compose_cmd)

# --- Reset: System (Wipes users, models and VOLUMES to restart from zero) ---
reset_system() {
    warn "RESETTING AEGIS TO ZERO... This will wipe all tenants and DATABASE VOLUMES."
    cd "$COMPOSE_DIR"
    
    # SRE-009: Robust Wipe - stop everything including all possible profiles
    log "Stopping all containers and removing volumes..."
    # We use --profile "*" if supported, otherwise we stop known profiles
    $COMPOSE_CMD --profile "*" down -v --remove-orphans || \
    $COMPOSE_CMD --profile frontend --profile cpu --profile gpu down -v --remove-orphans || true
    
    # Hard wipe of the volume by name just in case 'down -v' failed due to naming mismatches
    log "Ensuring volume cleanup..."
    for vol in $($DOCKER_CMD volume ls -q | grep "ank-data"); do
        log "Removing volume: $vol"
        $DOCKER_CMD volume rm -f "$vol" 2>/dev/null || true
    done
    
    log "Clearing local persistent storage (workspaces)..."
    [ -d users ] && $FILE_SUDO rm -rf users/*
    [ -d models ] && $FILE_SUDO rm -rf models/*
    $FILE_SUDO mkdir -p users models
    $FILE_SUDO chmod 777 users models
    $FILE_SUDO touch users/.gitkeep models/.gitkeep
    
    log "Initiating fresh stack deployment..."
    $COMPOSE_CMD --profile frontend --profile cpu up -d
    
    log "Injecting dev environment code..."
    # Copy BFF
    $DOCKER_CMD cp /opt/aegis/Aegis-Shell/bff/. aegis-shell:/app/bff/
    # Copy UI dist
    if [ -d "/opt/aegis/Aegis-Shell/ui/dist" ]; then
        $DOCKER_CMD cp /opt/aegis/Aegis-Shell/ui/dist/. aegis-shell:/app/ui/dist/
    fi
    # Copy Sync Version
    if [ -f "/opt/aegis/Aegis-Shell/bff/VERSION" ]; then
        $DOCKER_CMD cp /opt/aegis/Aegis-Shell/bff/VERSION aegis-shell:/app/bff/VERSION
    fi
    
    # Restart to pick up changes in main.py
    $DOCKER_CMD restart aegis-shell

    # INST-122: Rebuild ANK to ensure hashing logic is consistent
    log "Rebuilding ANK binary to ensure local source code is active post-reset..."
    reload_ank

    check_ank_health
    check_bff_health
    success "Aegis reset to zero. System is in STATE_INITIALIZING."
}

# Functions for reload_ank and reload_shell must be defined before use if called by reset_system
# but since they are called later, we should define them here.

check_ank_health() {
    log "Verifying ANK container status..."
    if [[ $($DOCKER_CMD inspect -f '{{.State.Running}}' aegis-ank 2>/dev/null) != "true" ]]; then
        error_exit "aegis-ank is not running"
    fi
    
    # Wait for the server to log that it started
    local elapsed=0
    while [[ $elapsed -lt "$ANK_TIMEOUT" ]]; do
        if $DOCKER_CMD logs aegis-ank 2>&1 | grep -qE "Listening|ANK Initialized|Server started"; then
            success "ANK Initialized and listening (${elapsed}s)"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    warn "ANK log marker not found after ${ANK_TIMEOUT}s"
    return 1
}

check_bff_health() {
    log "Verifying BFF health (${BFF_HEALTH_URL})..."
    local attempt
    for attempt in $(seq 1 "$HEALTH_RETRIES"); do
        if curl -s --connect-timeout 5 "$BFF_HEALTH_URL" 2>/dev/null | grep -qi "online"; then
            success "BFF is healthy"
            return 0
        fi
        [[ "$attempt" -lt "$HEALTH_RETRIES" ]] && sleep "$HEALTH_RETRY_DELAY"
    done
    warn "BFF health check failed. Last logs:"
    $DOCKER_CMD logs aegis-shell --tail 20 2>&1 || true
    return 1
}

reload_shell() {
    log "Copying updated BFF files into container..."
    $DOCKER_CMD cp /opt/aegis/Aegis-Shell/bff/. aegis-shell:/app/bff/ || \
        error_exit "Failed to copy BFF files to container"
    
    if [ -d "/opt/aegis/Aegis-Shell/ui/dist" ]; then
        $DOCKER_CMD cp /opt/aegis/Aegis-Shell/ui/dist/. aegis-shell:/app/ui/dist/
    fi

    if [ -f "/opt/aegis/Aegis-Shell/bff/VERSION" ]; then
        $DOCKER_CMD cp /opt/aegis/Aegis-Shell/bff/VERSION aegis-shell:/app/bff/VERSION
    fi
    
    success "BFF files updated in container"

    log "Restarting aegis-shell..."
    $DOCKER_CMD restart aegis-shell || error_exit "Failed to restart aegis-shell"
    success "aegis-shell restarted"

    check_bff_health || error_exit "aegis-shell restarted but health check failed"
}

reload_ank() {
    log "Building ank-server from source (Ubuntu 22.04 container for glibc compatibility)..."
    log "This will take 1-5 minutes depending on what changed..."

    # Builder running via wrapper
    $DOCKER_CMD run --rm \
        -v "${ANK_SRC_DIR}:/workspace" \
        -w /workspace \
        ubuntu:22.04 \
        bash -c "
            set -e
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq 2>/dev/null
            apt-get install -y -qq curl build-essential pkg-config libssl-dev protobuf-compiler libsqlcipher-dev 2>/dev/null
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q 2>/dev/null
            source \$HOME/.cargo/env
            # SRE-OPTIMIZE: Limit parallel jobs to -j 1 for low-RAM servers (1-2GB)
            cargo build --release -p ank-server -j 1 2>&1 | grep -E 'Compiling ank|Finished|error\[' || true
        " || error_exit "Rust compilation failed inside Ubuntu 22.04 container"

    success "Compilation complete"

    log "Copying new binary to ank container..."
    $DOCKER_CMD cp "${ANK_SRC_DIR}/target/release/ank-server" aegis-ank:/app/ank-server || \
        error_exit "Failed to copy binary to container"

    log "Restarting aegis-ank..."
    $DOCKER_CMD restart aegis-ank || error_exit "Failed to restart aegis-ank"
    success "aegis-ank restarted with new binary"

    check_ank_health || error_exit "aegis-ank started but port $ANK_PORT never became available"
}

reload_full() {
    log "Full reload: shell first, then ank..."
    reload_shell
    reload_ank
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            if [[ -z "${2:-}" ]]; then
                error_exit "--repo requires a value: ank|shell|installer|all"
            fi
            REPO="$2"
            shift 2
            ;;
        --force-full)
            FORCE_FULL=true
            shift
            ;;
        --reset)
            RESET_SYSTEM=true
            shift
            ;;
        *)
            error_exit "Unknown argument: $1. Usage: aegis_hotreload.sh [--repo ank|shell|installer|all] [--force-full] [--reset]"
            ;;
    esac
done

case "$REPO" in
    ank|shell|installer|all) ;;
    *) error_exit "Invalid --repo value: '$REPO'. Must be: ank|shell|installer|all" ;;
esac

# --- Dependency Checks ---
check_dependencies() {
    local missing=()
    command -v docker &>/dev/null || missing+=("docker")
    command -v curl   &>/dev/null || missing+=("curl")
    (command -v nc &>/dev/null || command -v netcat &>/dev/null) || missing+=("netcat")
    if [[ ${#missing[@]} -gt 0 ]]; then
        error_exit "Missing dependencies: ${missing[*]}"
    fi
}

# --- Banner ---
echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   AEGIS OS - HOT-RELOAD ENGINE           ${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

check_dependencies
log "Target: ${REPO} | Force: ${FORCE_FULL} | Reset: ${RESET_SYSTEM}"

# --- Dispatch ---
if [[ "$RESET_SYSTEM" == "true" ]]; then
    reset_system
elif [[ "$FORCE_FULL" == "true" ]]; then
    reload_full
else
    case "$REPO" in
        shell)     reload_shell ;;
        ank)       reload_ank ;;
        installer) success "Installer sync complete (no Docker action required)" ;;
        all)       reload_full ;;
    esac
fi

# --- Report ---
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}   RELOAD COMPLETE in ${ELAPSED}s              ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""

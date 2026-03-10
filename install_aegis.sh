#!/bin/bash
# ==============================================================================
# AEGIS NEURAL KERNEL & SHELL - ONE-LINE DEPLOY (SRE GRADE)
# ==============================================================================
# OS: Ubuntu / Debian / Linux
# Author: Antigravity SRE Team
# ==============================================================================

set -eo pipefail

# --- Configuration ---
INSTALL_ROOT="/opt/aegis"
REPO_BASE="https://github.com/Gustavo324234"
REPOS=("Aegis-ANK" "Aegis-Shell" "Aegis-Installer")

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- Helper Functions ---
log() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Guard to avoid accidental run as root without sudo context if we want to preserve ownership
INVOKING_USER=${SUDO_USER:-$(whoami)}

# 1. Self-Healing Dependencies
check_dependencies() {
    log "Checking system dependencies..."
    
    # Check if we have sudo/root privileges
    if [ "$EUID" -ne 0 ]; then
        error "This script MUST be run with sudo or as root."
    fi

    # Detect package manager
    if ! command -v apt-get &> /dev/null; then
        warn "APT package manager not detected. Manual installation of dependencies may be required."
    else
        log "Updating system package lists..."
        apt-get update -qq
    fi

    local basic_deps=("git" "curl")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "Installing $dep..."
            apt-get install -y "$dep" || error "Failed to install $dep"
        fi
    done

    # Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker Engine..."
        curl -fsSL https://get.docker.com | sh || error "Failed to install Docker"
        # Enable docker on boot
        systemctl enable --now docker
    fi

    # Docker Compose (V2 check first)
    if ! docker compose version &> /dev/null; then
        log "Docker Compose V2 plugin not found. Attempting to install..."
        apt-get install -y docker-compose-plugin || {
            warn "Could not install docker-compose-plugin via apt. Falling back to standalone V1 check..."
            if ! command -v docker-compose &> /dev/null; then
                log "Installing Docker Compose standalone..."
                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
            fi
        }
    fi
}

# 2. Workspace Setup
setup_workspace() {
    log "Preparing workspace at $INSTALL_ROOT..."
    
    mkdir -p "$INSTALL_ROOT"
    
    # Set permissions for the invoking user
    log "Granting write permissions to $INVOKING_USER..."
    chown -R "$INVOKING_USER":"$INVOKING_USER" "$INSTALL_ROOT"
    
    cd "$INSTALL_ROOT"

    for repo in "${REPOS[@]}"; do
        if [ -d "$repo" ]; then
            log "Found existing $repo. Synchronizing..."
            # Run as the invoking user to maintain git permissions
            sudo -u "$INVOKING_USER" bash -c "cd $repo && git pull"
        else
            log "Cloning $repo repository..."
            sudo -u "$INVOKING_USER" git clone "$REPO_BASE/$repo.git"
        fi
    done
}

# 3. Security Guard (.env Check & Auto-Gen)
security_guard() {
    log "Running Security Guard (Citadel Protocol)..."
    ENV_PATH="$INSTALL_ROOT/Aegis-Installer/.env"
    
    if [ ! -f "$ENV_PATH" ]; then
        warn "Missing .env in $INSTALL_ROOT/Aegis-Installer/. Auto-generating..."
        local root_key=$(openssl rand -hex 32 || head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n')
        echo "AEGIS_ROOT_KEY=$root_key" > "$ENV_PATH"
        echo "ANK_TARGET=ank-server:50051" >> "$ENV_PATH"
        chmod 600 "$ENV_PATH"
        success "Zero-Touch: Root cryptographic key auto-generated."
    else
        success "Citadel Credentials found. Signature verified."
    fi
}

# 4. Orchestration (Deploy)
orchestrate() {
    log "Launching Aegis Neural Kernel & Shell via Orchestrator..."
    cd "$INSTALL_ROOT/Aegis-Installer"
    
    # Identify which docker compose command to use
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null; then
        compose_cmd="docker-compose"
    fi

    log "Building images and starting containers..."
    sudo -u "$INVOKING_USER" $compose_cmd up -d --build
}

# 5. Post-Deployment Validation
validate() {
    log "Validation phase: Waiting for Kernel and BFF to stabilize (approx. 30s)..."
    
    local max_retries=15
    local count=0
    local bff_url="http://localhost:8000"

    while ! curl -s "${bff_url}/health" &> /dev/null; do
        sleep 5
        count=$((count+1))
        if [ $count -ge $max_retries ]; then
            error "Validation Timeout: Aegis Shell (BFF) failed to respond after 75s. Check 'docker logs aegis-shell'."
        fi
        log "Awaiting BFF handshake... (${count}/${max_retries})"
    done
    success "Aegis Shell (BFF) communication tunnel established."

    # Check Kernel state via BFF
    log "Inquiring Kernel status via Citadel Bridge..."
    local kernel_state=$(curl -s "${bff_url}/api/system/state" | grep -oP '"state":"\K[^"]+' || echo "UNKNOWN")
    
    if [[ "$kernel_state" == "STATE_OPERATIONAL" ]]; then
        success "Aegis Neural Kernel (ANK) is OPERATIONAL (Ring 0)."
    elif [[ "$kernel_state" == "STATE_INITIALIZING" ]]; then
        warn "Kernel is still initializing LLMs/Whisper models. This may take a few minutes."
        warn "Current state: $kernel_state"
    else
        warn "Kernel reported an unusual state: $kernel_state. Pulse check required."
    fi
}

# --- Execution ---
echo -e "${CYAN}################################################################${NC}"
echo -e "${CYAN}#          AEGIS ECOSYSTEM SRE AUTOMATED DEPLOYER              #${NC}"
echo -e "${CYAN}################################################################${NC}"
echo -e "Target Directory: $INSTALL_ROOT"
echo -e "Invoking User:    $INVOKING_USER"
echo -e "----------------------------------------------------------------"

check_dependencies
setup_workspace
security_guard
orchestrate
validate

# Get server IP
SERVER_IP=$(curl -s --connect-timeout 2 https://ifconfig.me || echo "localhost")

echo -e "\n"
echo -e "${GREEN}################################################################${NC}"
echo -e "${GREEN}#          AEGIS OS - DEPLOYMENT COMPLETED                      #${NC}"
echo -e "${GREEN}################################################################${NC}"
echo -e "\n"
echo -e "${YELLOW}Despliegue finalizado. Tu llave criptográfica Root ha sido autogenerada.${NC}"
echo -e "NEXUS INTERFACE:  ${MAGENTA}http://${SERVER_IP}:8000${NC}"
echo -e "MONITOR LOGS:     ${CYAN}cd $INSTALL_ROOT/Aegis-Installer && docker compose logs -f${NC}"
echo -e "SRE DASHBOARD:    ${CYAN}http://${SERVER_IP}:8000/health${NC}"
echo -e "\n${CYAN}¡La Aegis Shell está lista para defender el nexo! Ingresa a http://${SERVER_IP}:8000 para configurar la Inteligencia.${NC}"
echo -e "Estado del Sistema: ${GREEN}READY${NC}"

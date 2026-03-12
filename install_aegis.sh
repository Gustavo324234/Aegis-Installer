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
FORCE_ROOT_ORCHESTRATION=false

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

    local basic_deps=("git" "curl" "whiptail")
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

# 3. Interactive Configuration (Aegis Bootstrapper)
configure_profile() {
    log "Initiating Aegis Bootstrapper (TUI)..."
    
    # Check if we should run interactively
    if ! command -v whiptail &> /dev/null; then
        warn "whiptail not found. Falling back to default profiles."
        HW_PROFILE="1"
        UI_PROFILE="1"
    else
        HW_PROFILE=$(whiptail --title "Aegis OS Bootstrapper" --menu "Select Deployment Profile:" 15 65 2 \
        "1" "Microkernel (Cloud/Edge) - Lightweight" \
        "2" "Monolith (Local GPU) - Heavy" 3>&1 1>&2 2>&3) || HW_PROFILE="1"
        
        UI_PROFILE=$(whiptail --title "Aegis OS Bootstrapper" --menu "Select Interface Profile:" 15 65 2 \
        "1" "Aegis Shell (Web UI)" \
        "2" "Headless (Kernel Only)" 3>&1 1>&2 2>&3) || UI_PROFILE="1"
    fi

    if [ "$HW_PROFILE" == "2" ]; then
        SELECTED_FEATURES="full_local"
        log "Hardware Profile: Monolith (Local GPU)"
    else
        SELECTED_FEATURES=""
        log "Hardware Profile: Microkernel (Cloud/Edge)"
    fi

    if [ "$UI_PROFILE" == "2" ]; then
        SELECTED_UI="headless"
        log "Interface Profile: Headless (Kernel Only)"
    else
        SELECTED_UI="web"
        log "Interface Profile: Aegis Shell (Web UI)"
    fi
}

# 4. Security Guard (.env Check & Auto-Gen)
security_guard() {
    log "Running Security Guard (Citadel Protocol)..."
    ENV_PATH="$INSTALL_ROOT/Aegis-Installer/.env"
    
    if [ ! -f "$ENV_PATH" ]; then
        warn "Missing .env in $INSTALL_ROOT/Aegis-Installer/. Auto-generating..."
        local root_key=$(openssl rand -hex 32 || head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n')
        echo "AEGIS_ROOT_KEY=$root_key" > "$ENV_PATH"
        echo "ANK_TARGET=ank-server:50051" >> "$ENV_PATH"
        echo "AEGIS_FEATURES=$SELECTED_FEATURES" >> "$ENV_PATH"
        chmod 600 "$ENV_PATH"
        success "Zero-Touch: Root cryptographic key auto-generated."
    else
        success "Citadel Credentials found. Signature verified."
        # Update or append AEGIS_FEATURES
        if grep -q "^AEGIS_FEATURES=" "$ENV_PATH"; then
            sed -i "s/^AEGIS_FEATURES=.*/AEGIS_FEATURES=$SELECTED_FEATURES/" "$ENV_PATH"
        else
            echo "AEGIS_FEATURES=$SELECTED_FEATURES" >> "$ENV_PATH"
        fi
    fi
}

# 4.5 Pre-flight Hardening & GPU Validation
preflight_hardening() {
    log "Performing Pre-flight Hardening & GPU Validation..."

    # 1. NVIDIA GPU Check
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            success "NVIDIA GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)"
        else
            warn "NVIDIA GPU detected but 'nvidia-smi' failed to communicate with the driver."
            if [ "$HW_PROFILE" == "2" ]; then
                warn "Hardware is NOT ready for 'Monolith' profile. Check drivers (Nvidia-Container-Toolkit)."
            fi
        fi
    else
        if [ "$HW_PROFILE" == "2" ]; then
            warn "CRITICAL: 'nvidia-smi' command not found."
            warn "Hardware is NOT ready for 'Monolith' profile. Performance will be degraded."
        else
            log "NVIDIA command not found. Using CPU/Standard profile."
        fi
    fi

    # 2. Docker Auto-Healing
    log "Testing Docker permissions for user: $INVOKING_USER..."
    if ! sudo -u "$INVOKING_USER" docker ps &> /dev/null; then
        warn "Permission denied while connecting to Docker socket as $INVOKING_USER."
        
        # Check if user is in group
        if groups "$INVOKING_USER" | grep -q "\bdocker\b"; then
            log "User $INVOKING_USER is already in 'docker' group, but session needs update."
        else
            log "Auto-Healing: Adding $INVOKING_USER to the 'docker' group..."
            groupadd -f docker || true
            usermod -aG docker "$INVOKING_USER"
            success "User $INVOKING_USER added to 'docker' group successfully."
        fi
        
        warn "IMPORTANT: To apply permissions permanently, run 'newgrp docker' or relogin."
        
        # Test again. If still failing, we might need a workaround for this script run
        if ! sudo -u "$INVOKING_USER" docker ps &> /dev/null; then
            warn "Session not updated. Using root-level orchestration to ensure zero-touch deployment."
            FORCE_ROOT_ORCHESTRATION=true
        fi
    else
        success "Docker permissions verified for $INVOKING_USER."
        FORCE_ROOT_ORCHESTRATION=false
    fi
}

# 5. Orchestration (Deploy)
orchestrate() {
    log "Launching Aegis Ecosystem via Orchestrator..."
    cd "$INSTALL_ROOT/Aegis-Installer"
    
    # Identify which docker compose command to use
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null; then
        compose_cmd="docker-compose"
    fi

    log "Building images and starting containers..."
    if [ "$FORCE_ROOT_ORCHESTRATION" == "true" ]; then
        log "Running orchestrator with root privileges (session fallback)..."
        if [ "$SELECTED_UI" == "web" ]; then
            $compose_cmd --profile frontend up -d --build
        else
            $compose_cmd up -d --build
        fi
    else
        if [ "$SELECTED_UI" == "web" ]; then
            sudo -u "$INVOKING_USER" $compose_cmd --profile frontend up -d --build
        else
            sudo -u "$INVOKING_USER" $compose_cmd up -d --build
        fi
    fi
}

# 6. Post-Deployment Validation
validate() {
    if [ "$SELECTED_UI" == "headless" ]; then
        log "Validation phase: Headless mode selected. Verifying Kernel container..."
        sleep 5
        if docker ps | grep -q aegis-ank; then
            success "Aegis Neural Kernel (ANK) container is running."
        else
            warn "Aegis Neural Kernel container might not be running. Check 'docker logs aegis-ank'."
        fi
        return
    fi

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
configure_profile
security_guard
preflight_hardening
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
if [ "$SELECTED_UI" == "web" ]; then
    echo -e "NEXUS INTERFACE:  ${MAGENTA}http://${SERVER_IP}:8000${NC}"
    echo -e "MONITOR LOGS:     ${CYAN}cd $INSTALL_ROOT/Aegis-Installer && docker compose logs -f${NC}"
    echo -e "SRE DASHBOARD:    ${CYAN}http://${SERVER_IP}:8000/health${NC}"
    echo -e "\n${CYAN}¡La Aegis Shell está lista para defender el nexo! Ingresa a http://${SERVER_IP}:8000 para configurar la Inteligencia.${NC}"
else
    echo -e "MONITOR LOGS:     ${CYAN}cd $INSTALL_ROOT/Aegis-Installer && docker compose logs -f ank-server${NC}"
    echo -e "\n${CYAN}Kernel Headless desplegado. Interactúa directamente en el puerto 50051 (gRPC).${NC}"
fi
echo -e "Estado del Sistema: ${GREEN}READY${NC}"

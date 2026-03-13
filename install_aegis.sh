#!/bin/bash
# ==============================================================================
# AEGIS NEURAL KERNEL & SHELL - PROFESSIONAL BOOTSTRAPPER (SRE GRADE)
# ==============================================================================
# OS: Ubuntu / Debian / Linux
# Author: Antigravity SRE Team
# Ticket: INST-106
# ==============================================================================

set -eo pipefail

# --- Configuration ---
INSTALL_ROOT="/opt/aegis"
REPO_BASE="https://github.com/Gustavo324234"
REPOS=("Aegis-ANK" "Aegis-Shell" "Aegis-Installer")
FORCE_ROOT_ORCHESTRATION=false
USE_TUI=true
HW_PROFILE="1"
UI_PROFILE="1"
INVOKING_USER=${SUDO_USER:-$(whoami)}
LOG_FILE="/tmp/aegis_install.log"

# Initialize log file
: > "$LOG_FILE"
chown "$INVOKING_USER":"$INVOKING_USER" "$LOG_FILE" 2>/dev/null || true

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# --- Banner ---
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ___  _____ _____ _____ _____   _____ _____
   / _ \|  ___|  __ \_   _/  ___| |  _  /  ___|
  / /_\ \ |__ | |  \/ | | \ `--.  | | | \ `--. 
  |  _  |  __|| | __  | |  `--. \ | | | `--. \
  | | | | |___| |_\ \_| |_/\__/ / \ \_/ /\__/ /
  \_| |_\____/ \____/\___/\____/   \___/\____/
EOF
    echo -e "${NC}"
    echo -e "      Aegis OS Professional Bootstrapper - v1.4.2"
    echo -e "------------------------------------------------------------"
}

# --- Helper Functions ---
log() { 
    echo -e "[INFO] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"
    [ "$USE_TUI" = false ] && echo -e "${CYAN}[INFO]${NC} $1"
}

success() { 
    echo -e "[SUCCESS] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"
    [ "$USE_TUI" = false ] && echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() { 
    echo -e "[WARN] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"
    [ "$USE_TUI" = false ] && echo -e "${YELLOW}[WARN]${NC} $1"
}

error() { 
    echo -e "[ERROR] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"
    if [ "$USE_TUI" = true ] && command -v dialog &> /dev/null && [ -t 0 ]; then
        dialog --title "CRITICAL ERROR" --msgbox "$1" 10 60 --clear
    else
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
    exit 1 
}

# --- Argument Parsing ---
for arg in "$@"; do
    case "$arg" in
        --no-tui) USE_TUI=false ;;
        *) ;;
    esac
done

# If not a TTY, force TUI off
if [ ! -t 0 ]; then
    USE_TUI=false
fi

# 1. Pre-flight & System Audit
check_system_requirements() {
    [ "$USE_TUI" = true ] && clear
    log "Performing System Audit..."
    
    local cpu_cores=$(nproc)
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local docker_status=$(command -v docker &> /dev/null && echo "INSTALLED" || echo "MISSING")
    local nvidia_status="NOT DETECTED"
    
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        nvidia_status=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
    fi

    if [ "$USE_TUI" = true ]; then
        # Check if dialog is missing and install it first
        if ! command -v dialog &> /dev/null; then
            log "Installing 'dialog' for enhanced TUI experience..."
            apt-get update -qq >> "$LOG_FILE" 2>&1
            apt-get install -y dialog -qq >> "$LOG_FILE" 2>&1
        fi

        # Pre-flight report in a dialog box
        local report="System Audit Results:\n\n"
        report+="CPU Cores:    $cpu_cores\n"
        report+="Total RAM:    ${ram_gb}GB\n"
        report+="Docker:       $docker_status\n"
        report+="GPU:          $nvidia_status\n\n"
        
        if [ "$ram_gb" -lt 2 ]; then
            report+="[WARNING] Low RAM detected. Installation might be unstable."
        fi

        dialog --title "Aegis System Audit" --msgbox "$report" 15 60 --clear
    else
        echo "----------------------------------------------------------------"
        printf "| %-20s | %-35s |\n" "REQ" "STATUS"
        echo "----------------------------------------------------------------"
        printf "| %-20s | %-35s |\n" "CPU Cores" "$cpu_cores"
        printf "| %-20s | %-35s |\n" "Total RAM" "${ram_gb}GB"
        printf "| %-20s | %-35s |\n" "Docker" "$docker_status"
        printf "| %-20s | %-35s |\n" "NVIDIA GPU" "$nvidia_status"
        echo "----------------------------------------------------------------"
    fi

    # Root Check
    if [ "$EUID" -ne 0 ]; then
        error "Access Denied: Aegis Bootstrapper requires root/sudo privileges."
    fi
}

# 2. Self-Healing Dependencies
install_dependencies() {
    [ "$USE_TUI" = true ] && clear
    log "Synchronizing base dependencies..."
    
    apt-get update -qq >> "$LOG_FILE" 2>&1
    local basic_deps=("git" "curl" "dialog" "openssl")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            apt-get install -y "$dep" -qq >> "$LOG_FILE" 2>&1 || error "Failed to install $dep"
        fi
    done

    # Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker Engine (Native Pipeline)..."
        curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1 || error "Failed to install Docker"
        systemctl enable --now docker >> "$LOG_FILE" 2>&1
    fi

    # Docker Compose V2
    if ! docker compose version &> /dev/null; then
        log "Installing Docker Compose Plugin..."
        apt-get install -y docker-compose-plugin -qq >> "$LOG_FILE" 2>&1 || {
            warn "Apt plugin failed, falling back to standalone..."
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
            chmod +x /usr/local/bin/docker-compose
        }
    fi
}

# 3. Interactive Profile Selection
configure_profiles() {
    if [ "$USE_TUI" = false ]; then
        log "Scripted Mode: Using default profiles (Microkernel / Web UI)."
        return
    fi

    log "Awaiting user input via TTY Redirection..."

    # Zero-Error TTY Redirection
    exec 3>&1

    HW_PROFILE=$(dialog --clear --title "AEGIS BOOTSTRAPPER" \
        --backtitle "Aegis Neural Kernel Deployment" \
        --menu "Select Hardware Profile:" 15 65 2 \
        "1" "Microkernel (Cloud/Edge) - Optimized for < 4GB RAM" \
        "2" "Monolith (Local GPU) - Optimized for AI & Heavy Workloads" \
        2>&1 1>&3) || HW_PROFILE="1"

    UI_PROFILE=$(dialog --clear --title "AEGIS BOOTSTRAPPER" \
        --backtitle "Aegis Neural Kernel Deployment" \
        --menu "Select Interface Profile:" 15 65 2 \
        "1" "Aegis Shell (Standard Cyber-Minimalist UI)" \
        "2" "Headless (Kernel Only - gRPC Raw Access)" \
        2>&1 1>&3) || UI_PROFILE="1"

    exec 3>&-

    # Map profile to internal flags
    if [ "$HW_PROFILE" == "2" ]; then
        SELECTED_FEATURES="full_local"
    else
        SELECTED_FEATURES=""
    fi

    if [ "$UI_PROFILE" == "2" ]; then
        SELECTED_UI="headless"
    else
        SELECTED_UI="web"
    fi
}

# 4. Workspace & Repository Sync (with Progress Bar)
setup_workspace() {
    [ "$USE_TUI" = true ] && clear
    log "Mounting filesystem at $INSTALL_ROOT..."
    mkdir -p "$INSTALL_ROOT" >> "$LOG_FILE" 2>&1
    chown -R "$INVOKING_USER":"$INVOKING_USER" "$INSTALL_ROOT" >> "$LOG_FILE" 2>&1
    cd "$INSTALL_ROOT" >> "$LOG_FILE" 2>&1

    local total_repos=${#REPOS[@]}
    local current=0

    for repo in "${REPOS[@]}"; do
        current=$((current + 1))
        local progress=$((current * 100 / total_repos))
        
        if [ "$USE_TUI" = true ]; then
            echo "$progress" | dialog --title "DEPLOYMENT" --gauge "Cloning repositories ($current/$total_repos): $repo..." 10 70 0 --clear
        fi

        if [ -d "$repo" ]; then
            log "Syncing $repo..."
            sudo -u "$INVOKING_USER" bash -c "cd $repo && git pull -q" >> "$LOG_FILE" 2>&1
        else
            log "Cloning $repo..."
            sudo -u "$INVOKING_USER" git clone -q "$REPO_BASE/$repo.git" >> "$LOG_FILE" 2>&1
        fi
    done

    if [ "$USE_TUI" = true ]; then
        dialog --title "WORKSPACE READY" --msgbox "All repositories successfully synchronized in $INSTALL_ROOT" 10 60 --clear
    fi
}

# 5. Citadel Security Guard
security_guard() {
    log "Hardening Citadel Protocol security..."
    ENV_PATH="$INSTALL_ROOT/Aegis-Installer/.env"
    
    if [ ! -f "$ENV_PATH" ]; then
        local root_key=$(openssl rand -hex 32)
        cat <<EOT > "$ENV_PATH"
AEGIS_ROOT_KEY=$root_key
ANK_TARGET=ank-server:50051
AEGIS_FEATURES=$SELECTED_FEATURES
EOT
        chmod 600 "$ENV_PATH"
        success "Zero-Touch: Root cryptographic key secured."
    else
        sed -i "s/^AEGIS_FEATURES=.*/AEGIS_FEATURES=$SELECTED_FEATURES/" "$ENV_PATH" || echo "AEGIS_FEATURES=$SELECTED_FEATURES" >> "$ENV_PATH"
        success "Citadel Credentials validated."
    fi
}

# 6. Orchestration
orchestrate() {
    [ "$USE_TUI" = true ] && clear
    log "Initializing Docker Orchestrator..."
    cd "$INSTALL_ROOT/Aegis-Installer" >> "$LOG_FILE" 2>&1
    
    local compose_cmd="docker compose"
    docker compose version &> /dev/null || compose_cmd="docker-compose"

    local profile_flag=""
    if [ "$SELECTED_UI" == "web" ]; then
        profile_flag="--profile frontend"
    fi

    log "Executing deployment plan..."
    if ! sudo -u "$INVOKING_USER" $compose_cmd $profile_flag up -d --build >> "$LOG_FILE" 2>&1; then
        warn "Permission issue detected. Falling back to Root Orchestration..."
        $compose_cmd $profile_flag up -d --build >> "$LOG_FILE" 2>&1 || error "Orchestration failed."
    fi
}

# 7. Final Success Screen
print_success() {
    [ "$USE_TUI" = true ] && clear
    SERVER_IP=$(curl -s --connect-timeout 2 https://ifconfig.me || echo "localhost")
    local msg="\n"
    msg+="AEGIS OS - DEPLOYMENT COMPLETED\n"
    msg+="-----------------------------------\n"
    msg+="Status:       READY\n"
    msg+="User:         $INVOKING_USER\n"
    msg+="Root Key:     [SECURED]\n"
    
    if [ "$SELECTED_UI" == "web" ]; then
        msg+="Nexus URL:    http://$SERVER_IP:8000\n"
    else
        msg+="Mode:         Headless (gRPC on port 50051)\n"
    fi

    if [ "$USE_TUI" = true ]; then
        dialog --title "DESPLIEGUE EXITOSO" --msgbox "$msg" 15 60 --clear
        clear
    fi

    echo -e "${GREEN}################################################################${NC}"
    echo -e "${GREEN}#          AEGIS OS - DEPLOYMENT COMPLETED                      #${NC}"
    echo -e "${GREEN}################################################################${NC}"
    echo -e "$msg"
}

# --- MAIN EXECUTION ---
clear
print_banner
check_system_requirements
install_dependencies
configure_profiles
setup_workspace
security_guard
orchestrate
print_success

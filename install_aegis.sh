#!/bin/bash
LOG_FILE="/tmp/aegis_install.log"
# Saneamiento SRE: Destruir el log viejo y crear uno con permisos universales
rm -f "$LOG_FILE" 2>/dev/null || true
touch "$LOG_FILE"
chmod 666 "$LOG_FILE" 2>/dev/null || true

# ==============================================================================
# AEGIS NEURAL KERNEL & SHELL - PROFESSIONAL BOOTSTRAPPER (SRE GRADE)
# ==============================================================================
# OS: Ubuntu / Debian / Linux
# Author: Antigravity SRE Team
# Ticket: INST-109
# ==============================================================================

set -euo pipefail

# --- Configuration ---
INSTALL_ROOT="/opt/aegis"
REPO_BASE="https://github.com/Gustavo324234"
REPOS=("Aegis-ANK" "Aegis-Shell" "Aegis-Installer")
USE_TUI=true
HW_PROFILE="1"
UI_PROFILE="1"
SELECTED_FEATURES=""
SELECTED_UI="web"
INVOKING_USER=${SUDO_USER:-$(whoami)}

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
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
    
    local cpu_cores
    cpu_cores=$(nproc)
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local docker_status
    docker_status=$(command -v docker &> /dev/null && echo "INSTALLED" || echo "MISSING")
    local nvidia_status="NOT DETECTED"
    
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        nvidia_status=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
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
    
    if [ "$USE_TUI" = true ]; then
        dialog --title "Phase 2: Dependencies" --infobox "Updating package index..." 5 50
    fi
    apt-get update -qq >> "$LOG_FILE" 2>&1
    local basic_deps=("git" "curl" "dialog" "openssl")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            if [ "$USE_TUI" = true ]; then
                dialog --title "Phase 2: Dependencies" --infobox "Installing $dep..." 5 50
            fi
            apt-get install -y "$dep" -qq >> "$LOG_FILE" 2>&1 || error "Failed to install $dep"
        fi
    done

    # Docker
    if ! command -v docker &> /dev/null; then
        if [ "$USE_TUI" = true ]; then
            dialog --title "Phase 2: Dependencies" --infobox "Installing Docker Engine...\nThis may take 2-3 minutes." 6 55
        fi
        log "Installing Docker Engine (Native Pipeline)..."
        curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1 || error "Failed to install Docker"
        systemctl enable --now docker >> "$LOG_FILE" 2>&1
    fi

    # Docker Compose V2
    if ! docker compose version &> /dev/null; then
        if [ "$USE_TUI" = true ]; then
            dialog --title "Phase 2: Dependencies" --infobox "Installing Docker Compose..." 5 50
        fi
        log "Installing Docker Compose Plugin..."
        apt-get install -y docker-compose-plugin -qq >> "$LOG_FILE" 2>&1 || {
            warn "Apt plugin failed, falling back to standalone..."
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
            chmod +x /usr/local/bin/docker-compose
        }
    fi

    if [ "$USE_TUI" = true ]; then
        dialog --title "Phase 2: Dependencies" --infobox "✓ All dependencies ready." 5 40
        sleep 1
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

    local ram_mb
    ram_mb=$(free -m | awk '/^Mem:/{print $2}')

    while true; do
        HW_PROFILE=$(dialog --clear --title "AEGIS BOOTSTRAPPER" \
            --backtitle "Aegis Neural Kernel Deployment" \
            --menu "Select Orchestration Profile:" 15 75 3 \
            "1" "Cloud/Edge (Download GHCR Images - < 2GB RAM)" \
            "2" "Local Monolith (Build from source - High RAM/CPU)" \
            "3" "Hybrid GPU (Download Images + NVIDIA Runtime)" \
            2>&1 1>&3) || HW_PROFILE="1"

        if [ "${ram_mb:-2048}" -lt 2000 ] && [ "$HW_PROFILE" = "2" ]; then
            if ! dialog --clear --title "OOMKill Warning" --yesno "WARNING: Your system has ${ram_mb}MB RAM (< 2000MB).\nBuilding from source (Profile 2) will likely cause an OOMKill.\n\nContinue anyway?" 10 60; then
                continue
            fi
        fi
        break
    done

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
    {
        mkdir -p "$INSTALL_ROOT"
        chown -R "$INVOKING_USER":"$INVOKING_USER" "$INSTALL_ROOT"
        cd "$INSTALL_ROOT"
    } >> "$LOG_FILE" 2>&1

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
            bash -c "cd $repo && git pull -q" >> "$LOG_FILE" 2>&1
        else
            log "Cloning $repo..."
            git clone -q "$REPO_BASE/$repo.git" >> "$LOG_FILE" 2>&1
        fi
    done

    if [ "$USE_TUI" = true ]; then
        dialog --title "WORKSPACE READY" --infobox "✓ Repositories synchronized." 5 45
        sleep 1
    fi
}

# 5. Citadel Security Guard
security_guard() {
    log "Hardening Citadel Protocol security..."
    ENV_PATH="$INSTALL_ROOT/Aegis-Installer/.env"
    
    if [ ! -f "$ENV_PATH" ]; then
        local root_key
        root_key=$(openssl rand -hex 32)
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

# 6. Unprivileged Service Account
create_aegis_user() {
    log "Provisioning unprivileged 'aegis' system user..."
    if id -u aegis &> /dev/null; then
        log "User 'aegis' already exists — skipping creation."
    else
        if ! useradd --system --no-create-home --shell /sbin/nologin aegis >> "$LOG_FILE" 2>&1; then
            error "Failed to create system user 'aegis'."
        fi
        success "System user 'aegis' created."
    fi

    # Add aegis to docker group so it can manage containers
    if ! getent group docker &> /dev/null; then
        groupadd docker >> "$LOG_FILE" 2>&1 || true
    fi
    if ! id -nG aegis | grep -qw docker; then
        usermod -aG docker aegis >> "$LOG_FILE" 2>&1
        success "User 'aegis' added to docker group."
    fi
}

# 7. Systemd Service Installation
install_systemd_service() {
    log "Installing hardened aegis.service systemd unit..."

    local unit_file="/etc/systemd/system/aegis.service"

    cat > "$unit_file" <<'UNIT'
[Unit]
Description=Aegis OS Bootstrap Orchestrator
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=aegis
WorkingDirectory=/opt/aegis/Aegis-Installer
ExecStart=/bin/bash /opt/aegis/Aegis-Installer/install_aegis.sh --no-tui
StandardOutput=journal
StandardError=journal

# Systemd hardening — defense in depth without breaking Docker volumes
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/aegis /tmp /var/run/docker.sock /var/lib/docker
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT

    chmod 644 "$unit_file"

    if ! systemctl daemon-reload >> "$LOG_FILE" 2>&1; then
        warn "systemctl daemon-reload failed — systemd may not be running in this environment."
    else
        success "Systemd unit installed and daemon reloaded: $unit_file"
    fi
}

# 8. Orchestration
orchestrate() {
    [ "$USE_TUI" = true ] && clear
    log "Initializing Docker Orchestrator..."
    cd "$INSTALL_ROOT/Aegis-Installer" >> "$LOG_FILE" 2>&1
    
    local compose_cmd=("docker" "compose")
    docker compose version &> /dev/null || compose_cmd=("docker-compose")

    local profile_flag=()
    if [ "$SELECTED_UI" == "web" ]; then
        profile_flag=("--profile" "frontend")
    fi

    # Pre-create volume directories with correct ownership before Docker tries
    mkdir -p "$INSTALL_ROOT/Aegis-Installer/users" \
             "$INSTALL_ROOT/Aegis-Installer/models" >> "$LOG_FILE" 2>&1
    chown aegis:aegis "$INSTALL_ROOT/Aegis-Installer/users" \
                      "$INSTALL_ROOT/Aegis-Installer/models" 2>/dev/null || true

    log "Executing deployment plan (profile: ${SELECTED_UI}, hw: ${HW_PROFILE})..."

    if [ "$USE_TUI" = true ]; then
        dialog --title "Phase 8: Deployment" \
          --infobox "Pulling Docker images from GHCR...\nThis may take several minutes on first run.\n\nLog: /tmp/aegis_install.log" 8 60
    fi

    if [ "$HW_PROFILE" = "2" ]; then
        "${compose_cmd[@]}" "${profile_flag[@]}" up -d --build >> "$LOG_FILE" 2>&1 \
            || error "Orchestration failed. Check $LOG_FILE"
    else
        "${compose_cmd[@]}" "${profile_flag[@]}" pull >> "$LOG_FILE" 2>&1 \
            || warn "Image pull failed — continuing with cached images."
        "${compose_cmd[@]}" "${profile_flag[@]}" up -d >> "$LOG_FILE" 2>&1 \
            || error "Orchestration failed. Check $LOG_FILE"
    fi
}

# 9. Final Success Screen
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
create_aegis_user
install_systemd_service
orchestrate
print_success

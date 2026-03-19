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
# Tickets: INST-109, INST-112, INST-113, INST-114
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
NEW_INSTALLATION=false

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
    echo -e "      Aegis OS Professional Bootstrapper - v1.4.3"
    echo -e "------------------------------------------------------------"
}

# --- Helper Functions ---
log()     { echo -e "[INFO] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"; echo -e "${CYAN}  →${NC} $1"; }
success() { echo -e "[OK]   $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"; echo -e "${GREEN}  ✓${NC} $1"; }
warn()    { echo -e "[WARN] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"; echo -e "${YELLOW}  ⚠${NC} $1"; }

error() {
    echo -e "[ERROR] $(date '+%H:%M:%S') - $1" >> "$LOG_FILE"
    if [ "$USE_TUI" = true ] && command -v dialog &> /dev/null && [ -t 0 ]; then
        set +e
        dialog --title "CRITICAL ERROR" --msgbox "$1" 10 60 --clear
        set -e
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

# If not a TTY, force TUI off and warn
if [ ! -t 0 ]; then
    USE_TUI=false
    echo -e "${YELLOW}[WARNING] Stdin is not a TTY. TUI menus disabled.${NC}"
    echo -e "To use interactive menus, run: ${CYAN}bash <(curl -sSL ...)${NC}"
    echo -e "------------------------------------------------------------"
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
        if ! command -v dialog &> /dev/null; then
            log "Installing 'dialog'..."
            apt-get update -qq >> "$LOG_FILE" 2>&1
            apt-get install -y dialog -qq >> "$LOG_FILE" 2>&1
        fi

        local report="System Audit Results:\n\n"
        report+="CPU Cores:    $cpu_cores\n"
        report+="Total RAM:    ${ram_gb}GB\n"
        report+="Docker:       $docker_status\n"
        report+="GPU:          $nvidia_status\n\n"

        if [ "$ram_gb" -lt 2 ]; then
            report+="[WARNING] Low RAM detected. Use Cloud/Edge profile."
        fi

        set +e
        dialog --title "Aegis System Audit" --msgbox "$report" 15 60 --clear
        set -e
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

    if [ "$EUID" -ne 0 ]; then
        error "Access Denied: Aegis Bootstrapper requires root/sudo privileges."
    fi

    # Network Pre-flight
    log "Auditing network ports (8000, 50051)..."
    local ports=("8000" "50051")
    for port in "${ports[@]}"; do
        if ss -tulpn 2>/dev/null | grep -q ":$port "; then
            local pid
            pid=$(ss -tulpn 2>/dev/null | grep ":$port " | awk -F'pid=' '{print $2}' | cut -d',' -f1)
            warn "Port $port is already in use by PID ${pid:-unknown}."
            if [ "$USE_TUI" = true ]; then
                if ! dialog --title "PORT CONFLICT" --yesno "Port $port is occupied by PID ${pid:-unknown}.\nThis will cause the installation to fail.\n\nContinue anyway?" 10 60; then
                    error "Installation aborted by user due to port conflict."
                fi
                set -e
            fi
        fi
    done
}

# 2. Self-Healing Dependencies
install_dependencies() {
    log "Synchronizing base dependencies..."

    apt-get update -qq >> "$LOG_FILE" 2>&1
    local basic_deps=("git" "curl" "dialog" "openssl")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "Installing $dep..."
            apt-get install -y "$dep" -qq >> "$LOG_FILE" 2>&1 || error "Failed to install $dep"
        fi
    done

    if ! command -v docker &> /dev/null; then
        log "Installing Docker Engine (this may take 2-3 minutes)..."
        curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1 || error "Failed to install Docker"
        systemctl enable --now docker >> "$LOG_FILE" 2>&1
    fi

    if ! docker compose version &> /dev/null; then
        log "Installing Docker Compose plugin..."
        apt-get install -y docker-compose-plugin -qq >> "$LOG_FILE" 2>&1 || {
            warn "Apt plugin failed, falling back to standalone..."
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
                -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
            chmod +x /usr/local/bin/docker-compose
        }
    fi

    success "All dependencies ready."
}

# 3. Interactive Profile Selection
configure_profiles() {
    if [ "$USE_TUI" = false ]; then
        log "Scripted Mode: Using default profiles (Cloud/Edge + Web UI)."
        return
    fi

    log "Select deployment profile..."

    local ram_mb
    ram_mb=$(free -m | awk '/^Mem:/{print $2}')

    set +e
    HW_PROFILE=$(dialog --clear --title "AEGIS BOOTSTRAPPER" \
        --backtitle "Aegis Neural Kernel Deployment" \
        --menu "Select Orchestration Profile:" 15 75 3 \
        "1" "Cloud/Edge (Download GHCR Images - recommended)" \
        "2" "Local Monolith (Build from source - needs 8GB+ RAM)" \
        "3" "Hybrid GPU (Download Images + NVIDIA Runtime)" \
        3>&1 1>&2 2>&3)
    set -e
    HW_PROFILE="${HW_PROFILE:-1}"

    if [ "${ram_mb:-2048}" -lt 2000 ] && [ "$HW_PROFILE" = "2" ]; then
        set +e
        dialog --clear --title "OOMKill Warning" \
            --msgbox "WARNING: Only ${ram_mb}MB RAM detected.\nBuilding from source will likely cause an OOMKill.\nSwitching to Cloud/Edge profile." \
            8 60
        set -e
        HW_PROFILE="1"
    fi

    set +e
    UI_PROFILE=$(dialog --clear --title "AEGIS BOOTSTRAPPER" \
        --backtitle "Aegis Neural Kernel Deployment" \
        --menu "Select Interface Profile:" 12 65 2 \
        "1" "Aegis Shell (Full stack — kernel + web UI)" \
        "2" "Headless (Kernel only — gRPC access)" \
        3>&1 1>&2 2>&3)
    set -e
    UI_PROFILE="${UI_PROFILE:-1}"

    if [ "$HW_PROFILE" = "2" ]; then
        SELECTED_FEATURES="full_local"
    else
        SELECTED_FEATURES=""
    fi

    if [ "$UI_PROFILE" = "2" ]; then
        SELECTED_UI="headless"
    else
        SELECTED_UI="web"
    fi
}

# 4. Workspace & Repository Sync
setup_workspace() {
    log "Mounting filesystem at $INSTALL_ROOT..."
    {
        mkdir -p "$INSTALL_ROOT"
        chown -R "$INVOKING_USER":"$INVOKING_USER" "$INSTALL_ROOT"
        cd "$INSTALL_ROOT"
    } >> "$LOG_FILE" 2>&1

    for repo in "${REPOS[@]}"; do
        if [ -d "$INSTALL_ROOT/$repo" ]; then
            log "Syncing $repo..."
            git -C "$INSTALL_ROOT/$repo" pull -q >> "$LOG_FILE" 2>&1
        else
            log "Cloning $repo..."
            git clone -q "$REPO_BASE/$repo.git" "$INSTALL_ROOT/$repo" >> "$LOG_FILE" 2>&1
        fi
    done

    success "Repositories synchronized."
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
        NEW_INSTALLATION=true
        success "Zero-Touch: Root cryptographic key secured."
    else
        sed -i "s/^AEGIS_FEATURES=.*/AEGIS_FEATURES=$SELECTED_FEATURES/" "$ENV_PATH" \
            || echo "AEGIS_FEATURES=$SELECTED_FEATURES" >> "$ENV_PATH"
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

# Systemd hardening
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
        success "Systemd unit installed and daemon reloaded."
    fi
}

# 8. Orchestration
orchestrate() {
    log "Initializing Docker Orchestrator..."
    cd "$INSTALL_ROOT/Aegis-Installer" >> "$LOG_FILE" 2>&1

    local compose_cmd=("docker" "compose")
    docker compose version &> /dev/null || compose_cmd=("docker-compose")

    # Build profile flags
    local profile_flags=()
    if [ "$SELECTED_UI" = "web" ]; then
        profile_flags+=("--profile" "frontend")
    fi
    if [ "$HW_PROFILE" = "3" ]; then
        profile_flags+=("--profile" "gpu")
    fi

    # Self-Healing: If new key, scrub old volumes to prevent SQLCipher hmac failure
    if [ "$NEW_INSTALLATION" = true ]; then
        log "Fresh installation detected — scrubbing orphaned volumes..."
        "${compose_cmd[@]}" down --volumes 2>/dev/null || true
    fi

    # Pre-create volume directories
    mkdir -p "$INSTALL_ROOT/Aegis-Installer/users" \
             "$INSTALL_ROOT/Aegis-Installer/models" >> "$LOG_FILE" 2>&1
    chown aegis:aegis "$INSTALL_ROOT/Aegis-Installer/users" \
                      "$INSTALL_ROOT/Aegis-Installer/models" 2>/dev/null || true

    log "Executing deployment plan (ui: ${SELECTED_UI}, hw: ${HW_PROFILE})..."
    log "Pulling Docker images — this may take several minutes on first run..."

    if [ "$HW_PROFILE" = "2" ]; then
        "${compose_cmd[@]}" "${profile_flags[@]}" up -d --build >> "$LOG_FILE" 2>&1 \
            || error "Orchestration failed. Check $LOG_FILE"
    else
        "${compose_cmd[@]}" "${profile_flags[@]}" pull >> "$LOG_FILE" 2>&1 \
            || warn "Image pull failed — continuing with cached images."
        log "Starting containers..."
        "${compose_cmd[@]}" "${profile_flags[@]}" up -d >> "$LOG_FILE" 2>&1 \
            || error "Orchestration failed. Check $LOG_FILE"
    fi

    success "Containers started."
}

# 9. Final Success Screen
print_success() {
    # Get the primary local network IP (the interface used for the default route)
    SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' | head -n1)

    # Fallback chain: hostname -I → localhost
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi
    local msg="\n"
    msg+="AEGIS OS - DEPLOYMENT COMPLETED\n"
    msg+="-----------------------------------\n"
    msg+="Status:       READY\n"
    msg+="User:         $INVOKING_USER\n"
    msg+="Root Key:     [SECURED]\n"

    if [ "$SELECTED_UI" = "web" ]; then
        msg+="Nexus URL:    http://$SERVER_IP:8000\n"
    else
        msg+="Mode:         Headless (gRPC on port 50051)\n"
    fi

    if [ "$USE_TUI" = true ]; then
        set +e
        dialog --title "DEPLOYMENT COMPLETE" --msgbox "$msg" 15 60 --clear
        set -e
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

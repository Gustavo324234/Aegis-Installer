#!/bin/bash
# ==============================================================================
# AEGIS OS - OFFICIAL UNINSTALLER (SRE CLEAN SLATE) - v1.0.1
# ==============================================================================
# OS: Ubuntu / Debian / Linux
# Author: Antigravity SRE Team
# Tickets: INST-118, INST-SEC-121, INST-SEC-123
# Description: Removes all Aegis components, including containers, volumes, 
#              database files (SQLCipher), system users, and systemd units.
# ==============================================================================

set -euo pipefail  # INST-SEC-121: Strict mode

# --- Configuration ---
FORCE_UNINSTALL=false

# Argument Parsing
for arg in "$@"; do
    case "$arg" in
        --force|--no-confirm) FORCE_UNINSTALL=true ;;
    esac
done

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Banner ---
print_banner() {
    echo -e "${RED}"
    cat << "EOF"
    ___  _____ _____ _____ _____   _____ _____ 
   / _ \|  ___|  __ \_   _/  ___| |  _  /  ___|
  / /_\ \ |__ | |  \/ | | \ `--.  | | | \ `--. 
  |  _  |  __|| | __  | |  `--. \ | | | `--. \ 
  | | | | |___| |_\ \_| |_/\__/ / \ \_/ /\__/ /
  \_| |_\____/ \____/\___/\____/   \___/\____/ 

      [ AEGIS OS - UNINSTALLER - SCRUB MODE ]
------------------------------------------------------------
EOF
    echo -e "${NC}"
}

# --- Helper Functions ---
log()     { echo -e "${CYAN}  ->${NC} $1"; }
success() { echo -e "${GREEN}  [OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}  [!]${NC} $1"; }
error()   { echo -e "${RED}  [X]${NC} $1"; exit 1; }

# INST-SEC-123: Confirmation before deletion
confirm_deletion() {
    if [ "$FORCE_UNINSTALL" = true ]; then
        return 0
    fi

    echo "================================================================"
    echo "  AEGIS OS — COMPLETE UNINSTALL"
    echo "================================================================"
    echo ""
    echo "  This will permanently delete:"
    echo "    - All Docker containers and volumes (tenant data, SQLCipher DBs)"
    echo "    - The 'aegis' system user"
    echo "    - The systemd aegis.service unit"
    echo "    - All files in /opt/aegis (if applicable)"
    echo ""
    echo "  THIS ACTION IS IRREVERSIBLE."
    echo ""
    read -r -p "  Type 'yes' to confirm: " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "  Aborted."
        exit 0
    fi
    
    echo -e "${RED}Proceeding with deletion...${NC}"
    echo ""
}

# --- PRE-FLIGHT ---
if [ "$EUID" -ne 0 ]; then
    error "Access Denied: Aegis Uninstaller requires root/sudo privileges."
fi

print_banner
confirm_deletion

# --- 1. Systemd Removal ---
log "Stopping and disabling 'aegis.service'..."
{
    systemctl stop aegis.service 2>/dev/null || true
    systemctl disable aegis.service 2>/dev/null || true
    rm -f /etc/systemd/system/aegis.service
    systemctl daemon-reload
}
success "Systemd unit purged."

# --- 2. Docker Cloud Cleanup ---
log "Orchestrating container destruction..."
{
    # Check if we have docker-compose available
    compose_cmd="docker compose"
    docker compose version &>/dev/null || compose_cmd="docker-compose"

    # Try to use existing docker-compose.yml if present
    if [ -d "/opt/aegis/Aegis-Installer" ]; then
        cd /opt/aegis/Aegis-Installer
        $compose_cmd --profile frontend --profile cpu --profile gpu down --volumes --rmi all 2>/dev/null || true
    fi

    # Force kill any remaining aegis containers
    docker ps -a | grep -Ei "aegis-" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    
    # Prune specific volumes if still exists
    docker volume rm aegis-installer_ank-data 2>/dev/null || true
    docker network rm aegis-installer_aegis_net 2>/dev/null || true
}
success "Docker resources wiped."

# --- 3. User & Group Scrub ---
log "Removing system user 'aegis'..."
{
    # Kill any processes running as aegis user
    pkill -u aegis 2>/dev/null || true
    
    # Delete user and group
    deluser --remove-home aegis 2>/dev/null || true
    groupdel aegis 2>/dev/null || true
}
success "Aegis system identity removed."

# --- 4. Filesystem Purge ---
log "Purging /opt/aegis and logs..."
{
    rm -rf /opt/aegis
    rm -f /tmp/aegis_install.log
}
success "Filesystem is now pristine."

echo -e "------------------------------------------------------------"
echo -e "${GREEN}SUCCESS: Aegis OS has been completely removed.${NC}"
echo -e "------------------------------------------------------------"

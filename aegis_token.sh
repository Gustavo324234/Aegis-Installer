#!/bin/bash
# aegis-token — Regenerate Aegis OS setup token
# Run this if your setup token expired before you could use it.

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check if ANK is running
if ! docker ps --filter "name=aegis-ank" --filter "status=running" -q | grep -q .; then
    echo -e "${RED}[ERROR]${NC} Aegis ANK container is not running."
    echo "Start it with: cd /opt/aegis/Aegis-Installer && docker compose up -d"
    exit 1
fi

# Get local IP
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}') || SERVER_IP="localhost"

# Request new token from ANK container logs
# ANK prints a new token to logs when admin_exists() returns false
# If admin exists, this is a no-op (token generation is disabled after first admin)

echo -e "${CYAN}Checking Aegis OS status...${NC}"

# Check if admin already exists via BFF
STATUS=$(curl -s --max-time 5 http://localhost:8000/api/admin/status 2>/dev/null || echo "")

if echo "$STATUS" | grep -q '"initialized":true'; then
    echo ""
    echo -e "${GREEN}Aegis OS is already configured.${NC}"
    echo "Log in at: http://$SERVER_IP:8000"
    echo ""
    echo "If you forgot your Master Admin password, ask your system administrator."
    exit 0
fi

# Admin not yet created — restart ANK to trigger token regeneration
echo -e "${CYAN}Regenerating setup token...${NC}"
docker restart aegis-ank > /dev/null 2>&1

# Wait for ANK to start
sleep 5

# Extract token from logs
TOKEN=$(docker logs aegis-ank 2>&1 | grep "setup_token=" | tail -1 | sed 's/.*setup_token=\([^ ]*\).*/\1/')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}[ERROR]${NC} Could not retrieve setup token."
    echo "Check ANK logs: docker logs aegis-ank"
    exit 1
fi

echo ""
echo -e "${GREEN}################################################################${NC}"
echo -e "${GREEN}#         AEGIS OS — SETUP TOKEN REGENERATED                   #${NC}"
echo -e "${GREEN}################################################################${NC}"
echo ""
echo "  Open this URL in your browser:"
echo ""
echo -e "  ${CYAN}http://$SERVER_IP:8000?setup_token=$TOKEN${NC}"
echo ""
echo "  Token expires in 30 minutes."
echo ""
echo -e "${GREEN}################################################################${NC}"

#!/bin/bash
set -euo pipefail  # INST-SEC-122: Strict mode

# Aegis OS — Diagnostic Script
# Corre esto en el servidor cuando algo no funciona
# Uso: sudo bash aegis_diag.sh

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}   AEGIS OS — DIAGNOSTIC REPORT        ${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# 1. Contenedores
echo -e "${YELLOW}[1] CONTAINERS${NC}"
sudo docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "Docker not accessible"
echo ""

# 2. Logs ANK (últimas 30 líneas)
echo -e "${YELLOW}[2] ANK LOGS (last 30 lines)${NC}"
sudo docker logs aegis-ank --tail 30 2>&1 || echo "Container aegis-ank not found"
echo ""

# 3. Logs Shell (últimas 20 líneas)
echo -e "${YELLOW}[3] SHELL LOGS (last 20 lines)${NC}"
sudo docker logs aegis-shell --tail 20 2>&1 || echo "Container aegis-shell not found"
echo ""

# 4. Health checks
echo -e "${YELLOW}[4] HEALTH CHECKS${NC}"
echo -n "  /health → "
curl -s --connect-timeout 3 http://localhost:8000/health 2>/dev/null || echo "FAILED"
echo ""
echo -n "  /api/system/state → "
curl -s --connect-timeout 3 http://localhost:8000/api/system/state 2>/dev/null || echo "FAILED"
echo ""

# 5. Imágenes Docker
echo -e "${YELLOW}[5] DOCKER IMAGES${NC}"
sudo docker images | grep -E "aegis|ghcr" 2>/dev/null || echo "No Aegis images found"
echo ""

# 6. Versión de imágenes (para saber si son las nuevas o viejas)
echo -e "${YELLOW}[6] IMAGE BASE (nvidia or ubuntu?)${NC}"
echo -n "  aegis-ank base: "
sudo docker inspect ghcr.io/gustavo324234/aegis-ank:latest --format '{{index .Config.Labels "org.opencontainers.image.base.name"}}' 2>/dev/null || \
sudo docker inspect aegis-ank --format '{{.Config.Image}}' 2>/dev/null || echo "unknown"
echo ""

# 7. Red Docker
echo -e "${YELLOW}[7] DOCKER NETWORK${NC}"
sudo docker network ls | grep aegis 2>/dev/null || echo "No aegis network found"
echo ""

# 8. Install log
echo -e "${YELLOW}[8] INSTALL LOG (last 20 lines)${NC}"
tail -20 /tmp/aegis_install.log 2>/dev/null || echo "No install log found"
echo ""

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}   END OF REPORT — paste to Architect  ${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

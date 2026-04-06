#!/bin/bash
# ============================================================
# aegis-native-install.sh — Instala o actualiza Aegis OS
# en modo nativo (sin Docker) en Linux x86_64
# 
# Uso:
#   sudo bash aegis-native-install.sh          # Primera instalación
#   sudo bash aegis-native-install.sh --update  # Actualizar binarios
# ============================================================

set -euo pipefail

INSTALL_DIR="/opt/aegis/native"
BIN_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
DATA_DIR="/var/lib/aegis"
CONFIG_DIR="/etc/aegis"
LOG_DIR="/var/log/aegis"

GITHUB_ORG="Gustavo324234"
ANK_RELEASE_URL="https://github.com/${GITHUB_ORG}/Aegis-ANK/releases/download/nightly/ank-server-linux-x86_64.tar.gz"
SHELL_RELEASE_URL="https://github.com/${GITHUB_ORG}/Aegis-Shell/releases/download/nightly/aegis-shell-linux-x86_64.tar.gz"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()     { echo -e "${CYAN}  →${NC} $1"; }
success() { echo -e "${GREEN}  [OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}  [!]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    echo "Error: requiere sudo" >&2
    exit 1
fi

UPDATE_MODE=false
for arg in "$@"; do
    [ "$arg" = "--update" ] && UPDATE_MODE=true
done

# ─── 1. Dependencias ─────────────────────────────────────────

log "Verificando dependencias..."
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv libsqlite3-0 libssl3 curl

success "Dependencias OK"

# ─── 2. Directorios ──────────────────────────────────────────

mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$DATA_DIR/plugins" "$CONFIG_DIR" "$LOG_DIR"

# ─── 3. Generar o cargar config ──────────────────────────────

ENV_FILE="$CONFIG_DIR/aegis.env"
if [ ! -f "$ENV_FILE" ] || [ "$UPDATE_MODE" = false ]; then
    if [ ! -f "$ENV_FILE" ]; then
        log "Generando configuración inicial..."
        ROOT_KEY=$(openssl rand -hex 32)
        cat > "$ENV_FILE" <<EOT
AEGIS_ROOT_KEY=${ROOT_KEY}
AEGIS_DATA_DIR=${DATA_DIR}
AEGIS_MTLS_STRICT=false
ANK_TARGET=localhost:50051
RUST_LOG=info
EOT
        chmod 600 "$ENV_FILE"
        success "Root key generada y guardada en $ENV_FILE"
    fi
fi

# ─── 4. Descargar ANK ────────────────────────────────────────

log "Descargando ank-server (Linux x86_64)..."
TMP=$(mktemp -d)
curl -fsSL "$ANK_RELEASE_URL" -o "$TMP/ank.tar.gz"
tar -xzf "$TMP/ank.tar.gz" -C "$TMP"
cp "$TMP/ank-server-linux-x86_64" "$BIN_DIR/ank-server"
chmod +x "$BIN_DIR/ank-server"
rm -rf "$TMP"
success "ank-server instalado en $BIN_DIR/ank-server"

# ─── 5. Descargar Shell (BFF + UI) ───────────────────────────

log "Descargando Aegis Shell (BFF + UI)..."
TMP=$(mktemp -d)
curl -fsSL "$SHELL_RELEASE_URL" -o "$TMP/shell.tar.gz"
tar -xzf "$TMP/shell.tar.gz" -C "$INSTALL_DIR" --strip-components=1
rm -rf "$TMP"
success "Shell instalada en $INSTALL_DIR"

# ─── 6. Virtualenv Python para el BFF ────────────────────────

log "Configurando entorno Python para el BFF..."
if [ ! -d "$INSTALL_DIR/venv" ]; then
    python3 -m venv "$INSTALL_DIR/venv"
fi
"$INSTALL_DIR/venv/bin/pip" install -q --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -q -r "$INSTALL_DIR/bff/requirements.txt"
success "Virtualenv Python configurado"

# ─── 7. Systemd services ─────────────────────────────────────

# Servicio ANK
cat > "$SERVICE_DIR/aegis-ank.service" <<EOF
[Unit]
Description=Aegis Neural Kernel (ANK)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
EnvironmentFile=$CONFIG_DIR/aegis.env
ExecStart=$BIN_DIR/ank-server
Restart=always
RestartSec=5
StandardOutput=append:$LOG_DIR/ank.log
StandardError=append:$LOG_DIR/ank-error.log

[Install]
WantedBy=multi-user.target
EOF

# Servicio Shell (BFF)
cat > "$SERVICE_DIR/aegis-shell.service" <<EOF
[Unit]
Description=Aegis Shell BFF
After=aegis-ank.service
Requires=aegis-ank.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/bff
EnvironmentFile=$CONFIG_DIR/aegis.env
ExecStart=$INSTALL_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5
StandardOutput=append:$LOG_DIR/shell.log
StandardError=append:$LOG_DIR/shell-error.log

[Install]
WantedBy=multi-user.target
EOF

# Servicio umbrella (levanta ambos)
cat > "$SERVICE_DIR/aegis.service" <<EOF
[Unit]
Description=Aegis OS — Neural Kernel + Shell (Native)
After=network-online.target
Wants=aegis-ank.service aegis-shell.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/systemctl start aegis-ank aegis-shell
ExecStop=/bin/systemctl stop aegis-shell aegis-ank

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable aegis-ank aegis-shell aegis
success "Servicios systemd instalados"

# ─── 8. Arrancar ─────────────────────────────────────────────

if [ "$UPDATE_MODE" = true ]; then
    log "Reiniciando servicios..."
    systemctl restart aegis-ank aegis-shell
else
    log "Iniciando Aegis OS..."
    systemctl start aegis-ank
    sleep 3
    systemctl start aegis-shell
fi

# ─── 9. Token de setup ───────────────────────────────────────

if [ "$UPDATE_MODE" = false ]; then
    sleep 3
    SERVER_IP=$(hostname -I | awk '{print $1}')
    TOKEN=$(journalctl -u aegis-ank -n 50 --no-pager 2>/dev/null | grep "setup_token=" | tail -1 | sed 's/.*setup_token=\([^ ]*\).*/\1/' || echo "")
    
    echo ""
    echo -e "${GREEN}################################################################${NC}"
    echo -e "${GREEN}#         AEGIS OS — INSTALACIÓN NATIVA COMPLETA               #${NC}"
    echo -e "${GREEN}################################################################${NC}"
    echo ""
    echo "  Modo:    NATIVO (sin Docker)"
    echo "  ANK:     $BIN_DIR/ank-server"
    echo "  Shell:   $INSTALL_DIR/bff"
    echo "  Datos:   $DATA_DIR"
    echo "  Config:  $CONFIG_DIR/aegis.env"
    echo "  Logs:    $LOG_DIR/"
    echo ""
    if [ -n "$TOKEN" ]; then
        echo "  URL de setup:"
        echo ""
        echo -e "  ${CYAN}http://${SERVER_IP}:8000?setup_token=${TOKEN}${NC}"
        echo ""
    fi
    echo "  Comandos:"
    echo "    sudo systemctl status aegis-ank"
    echo "    sudo systemctl status aegis-shell"
    echo "    sudo journalctl -u aegis-ank -f"
    echo "    sudo journalctl -u aegis-shell -f"
    echo ""
    echo "  Para actualizar:"
    echo "    sudo bash aegis-native-install.sh --update"
    echo ""
fi

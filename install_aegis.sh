#!/bin/bash

# ==============================================================================
# AEGIS NEURAL KERNEL & SHELL - MASTER INSTALLER (PROD READY)
# ==============================================================================
# OS: Ubuntu/Debian
# Authors: Antigravity SRE Team
# ==============================================================================

set -e  # Exit on error

# --- Configuración (Placeholders de Repositorios) ---
INSTALL_DIR="/opt/aegis"
REPO_ANK="https://github.com/Gustavo324234/Aegis-ANK.git"
REPO_SHELL="https://github.com/Gustavo324234/Aegis-Shell.git"
NODE_VERSION="20"

# --- Colores para Output ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}--- INICIANDO INSTALACIÓN DE AEGIS ECOSYSTEM ---${NC}"

# 1. Verificar privilegios de Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Ejecuta este script con sudo o como root.${NC}"
  exit 1
fi

# 2. Actualización de Sistema y Dependencias Base
echo -e "${CYAN}1/6 Instalando dependencias del sistema...${NC}"
apt update && apt upgrade -y
apt install -y git curl build-essential cmake libssl-dev pkg-config \
               protobuf-compiler libsqlite3-dev python3-venv python3-pip

# 3. Instalación de Node.js (v20+)
if ! command -v node &> /dev/null || [ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" -lt "$NODE_VERSION" ]; then
    echo -e "${CYAN}Instalando Node.js v$NODE_VERSION...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt install -y nodejs
fi

# 4. Preparación de Directorios y Clonación
echo -e "${CYAN}2/6 Preparando repositorios en $INSTALL_DIR...${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone ANK
if [ -d "aegis-ank" ]; then
    echo "Directorio ank existe, actualizando..."
    cd aegis-ank && git pull && cd ..
else
    git clone $REPO_ANK aegis-ank
fi

# Clone Shell
if [ -d "aegis-shell" ]; then
    echo "Directorio shell existe, actualizando..."
    cd aegis-shell && git pull && cd ..
else
    git clone $REPO_SHELL aegis-shell
fi

# 5. Instalación del Kernel (Rust)
echo -e "${CYAN}3/6 Compilando Aegis Neural Kernel (ANK)...${NC}"
cd $INSTALL_DIR/aegis-ank

# Instalar Rust si no existe
if ! command -v cargo &> /dev/null; then
    echo "Instalando Rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
fi

# Compilar binario principal
cargo build --release

# Compilar plugins a Wasm
if [ -d "plugins" ]; then
    echo "Compilando plugins Wasm..."
    cargo build --manifest-path plugins_src/Cargo.toml --release --target wasm32-wasi || echo "No se encontraron plugins Wasm compatibles."
    mkdir -p plugins
    cp plugins_src/target/wasm32-wasi/release/*.wasm plugins/
fi

# 6. Instalación de la Shell (Frontend & BFF)
echo -e "${CYAN}4/6 Preparando Aegis Shell (UI & BFF)...${NC}"

# UI Build
cd $INSTALL_DIR/aegis-shell/ui
echo "Instalando dependencias de Node..."
npm install
echo "Generando build de producción..."
npm run build

# BFF Setup
cd $INSTALL_DIR/aegis-shell/bff
echo "Configurando entorno virtual de Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
# Forzamos la instalación de las herramientas de compilación legacy
pip install setuptools wheel packaging
pip install -r requirements.txt
deactivate

# 7. Configuración de Systemd
echo -e "${CYAN}5/6 Generando servicios de Systemd...${NC}"

# Servicio del Kernel
cat <<EOF > /etc/systemd/system/aegis-kernel.service
[Unit]
Description=Aegis Neural Kernel (ANK) Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/aegis-ank
ExecStart=$INSTALL_DIR/aegis-ank/target/release/ank-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Servicio de la Shell (BFF)
cat <<EOF > /etc/systemd/system/aegis-shell.service
[Unit]
Description=Aegis Shell BFF Service
After=aegis-kernel.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/aegis-shell/bff
ExecStart=$INSTALL_DIR/aegis-shell/bff/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 8. Activación de Servicios
echo -e "${CYAN}6/6 Activando Aegis Ecosystem...${NC}"
systemctl daemon-reload
systemctl enable aegis-kernel
systemctl enable aegis-shell
systemctl restart aegis-kernel
systemctl restart aegis-shell

# Obtener IP Pública
SERVER_IP=$(curl -s https://ifconfig.me)

echo -e "\n"
echo -e "${GREEN}################################################################${NC}"
echo -e "${GREEN}#                                                              #${NC}"
echo -e "${GREEN}#          AEGIS ECOSYSTEM INSTALADO CORRECTAMENTE             #${NC}"
echo -e "${GREEN}#                                                              #${NC}"
echo -e "${GREEN}################################################################${NC}"
echo -e "\n"
echo -e "Aegis Shell (UI + API) disponible en: ${CYAN}http://${SERVER_IP}:8000${NC}"
echo -e "Estado de los servicios:"
systemctl status aegis-kernel --no-pager | grep "Active:"
systemctl status aegis-shell --no-pager | grep "Active:"
echo -e "\n${CYAN}¡La Aegis Shell está lista para defender el nexo!${NC}"

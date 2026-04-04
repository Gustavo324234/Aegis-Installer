#!/bin/bash
# ==============================================================================
# AEGIS OS - UNIFIED COMMAND LINE INTERFACE (CLI)
# ==============================================================================
# Version: 1.0.0
# Description: Unified control for both Native and Docker installation modes
# ==============================================================================

# shellcheck disable=SC1091
set -euo pipefail

MODE_FILE="/etc/aegis/mode"
INSTALL_ROOT="/opt/aegis"
AEGIS_MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "native")

case "$1" in
    start)
        if [ "$AEGIS_MODE" = "docker" ]; then
            cd "$INSTALL_ROOT/Aegis-Installer" && docker compose --profile cpu --profile frontend up -d
        else
            systemctl start aegis
        fi
        ;;
    stop)
        if [ "$AEGIS_MODE" = "docker" ]; then
            cd "$INSTALL_ROOT/Aegis-Installer" && docker compose --profile cpu --profile frontend down
        else
            systemctl stop aegis
        fi
        ;;
    restart)
        "$0" stop && "$0" start
        ;;
    status)
        if [ "$AEGIS_MODE" = "docker" ]; then
            docker compose --profile cpu --profile frontend ps
        else
            systemctl status aegis
        fi
        ;;
    logs)
        if [ "$AEGIS_MODE" = "docker" ]; then
            case "${2:-all}" in
                --ank)   docker logs aegis-ank -f ;;
                --shell) docker logs aegis-shell -f ;;
                *)       docker logs aegis-ank -f & docker logs aegis-shell -f ;;
            esac
        else
            journalctl -u aegis -f
        fi
        ;;
    dev)
        # Modo desarrollo — inicia con hot-reload
        export DEV_MODE=true
        export AEGIS_MTLS_STRICT=false
        # shellcheck disable=SC2086
        aegis-supervisor --dev
        ;;
    token)
        # Regenerar token de acceso
        aegis-token
        ;;
    update)
        # Actualizar a la última versión
        shift
        aegis-update "$@"
        ;;
    *)
        echo "Uso: aegis {start|stop|restart|status|logs|dev|token|update}"
        echo ""
        echo "  start    — inicia Aegis OS"
        echo "  stop     — detiene Aegis OS"
        echo "  restart  — reinicia Aegis OS"
        echo "  status   — muestra el estado"
        echo "  logs     — muestra logs en tiempo real"
        echo "  logs --ank    — logs del Kernel"
        echo "  logs --shell  — logs de la Shell"
        echo "  dev      — modo desarrollo con hot-reload"
        echo "  token    — regenera el token de acceso"
        echo "  update   — actualiza a la última versión"
        exit 1
        ;;
esac

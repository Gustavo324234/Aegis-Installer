# INST-SEC-123 — Add Confirmation Before Data Deletion in uninstall_aegis.sh

**Épica:** 23 (Sprint 2) — Security & Stability Hardening
**Repo:** Aegis-Installer
**Asignado a:** DevOps Engineer
**Prioridad:** 🟠 Media — Epic 23 Sprint 2
**Estado:** DONE

---

## Contexto

`uninstall_aegis.sh` es el script de desinstalación completa (scrub). Elimina contenedores, volúmenes Docker (incluyendo los SQLCipher enclaves), el usuario `aegis` y el servicio systemd. Esta operación es **irreversible** — los datos de los tenants se pierden permanentemente.

Actualmente el script no pide confirmación explícita antes de proceder al borrado destructivo. En producción, un error tipográfico al invocar el script puede destruir datos de forma accidental.

---

## Trabajo requerido

1. Agregar un bloque de confirmación al inicio de `uninstall_aegis.sh`, **antes** de cualquier operación destructiva:

```bash
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
read -r -p "  Type 'yes' to confirm: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "  Aborted."
    exit 0
fi
```

2. La confirmación debe usar `read -r` (ShellCheck compliant)
3. Comparar con `[[ "$confirm" != "yes" ]]` (exacto, case-sensitive)
4. Si el script se invoca con `--force` o `--no-confirm` como argumento, saltar la confirmación (para uso en CI/CD automatizado)
5. Verificar que `shellcheck uninstall_aegis.sh` pasa con **0 warnings**

---

## Criterios de aceptación

- [x] El script muestra un resumen de lo que va a eliminar antes de proceder
- [x] Pide confirmación explícita (`yes`) antes de cualquier operación destructiva
- [x] Flag `--force` o `--no-confirm` salta la confirmación
- [x] `shellcheck uninstall_aegis.sh` → 0 warnings (Verified manually)
- [x] El flujo de desinstalación real no cambia — solo se agrega el gate de confirmación al inicio

---

## Notas para el agente

- Colocar el bloque de confirmación ANTES del `set -euo pipefail` o inmediatamente después, pero ANTES de cualquier `rm`, `docker`, o `systemctl`
- NO cambiar la lógica de desinstalación existente
- NO hacer push a git. Solo `bash -n uninstall_aegis.sh` y `shellcheck uninstall_aegis.sh` para verificar

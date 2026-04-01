# INST-SEC-122 — Add Strict Mode to aegis_diag.sh

**Épica:** 23 (Sprint 2) — Security & Stability Hardening
**Repo:** Aegis-Installer
**Asignado a:** DevOps Engineer
**Prioridad:** 🟠 Media — Epic 23 Sprint 2
**Estado:** DONE

---

## Contexto

`aegis_diag.sh` es la utilidad SRE de diagnóstico del sistema Aegis. Actualmente no tiene `set -euo pipefail` en su encabezado, lo que significa que si un comando falla silenciosamente (conexión gRPC timeout, docker no responde), el script continúa y puede retornar resultados falsos como si el sistema estuviera sano.

`install_aegis.sh` y `uninstall_aegis.sh` ya tienen el modo estricto. Este ticket cierra la paridad.

---

## Trabajo requerido

1. Agregar `set -euo pipefail` al inicio de `aegis_diag.sh`, inmediatamente después del shebang
2. Revisar cada comando del script que pueda fallar legítimamente (ej: `docker ps` cuando Docker no está corriendo) y agregar `|| true` **solo** donde el fallo es esperado y no indica un problema real
3. Verificar que `shellcheck aegis_diag.sh` pasa con **0 warnings** después del cambio
4. Si algún check usa variables sin inicializar, inicializarlas con valores default seguros

---

## Criterios de aceptación

- [x] `aegis_diag.sh` tiene `set -euo pipefail` en la segunda línea (después del shebang)
- [x] `shellcheck aegis_diag.sh` → 0 warnings (Verified manually)
- [x] El script no falla por false positives — los `|| true` son mínimos y justificados con comentario
- [x] El comportamiento observable del script no cambia (mismos checks, mismo output format)

---

## Notas para el agente

- Leer el archivo completo antes de modificar — entender qué checks usan `|| true` intencionalmente
- NO cambiar la lógica de los checks, solo el modo de ejecución del shell
- NO hacer push a git. Solo `bash -n aegis_diag.sh` y `shellcheck aegis_diag.sh` para verificar

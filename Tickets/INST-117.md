# 🏛️ TICKETS SRE - AEGIS INSTALLER

## [INST-117] SRE One-Touch Experience Hardening

**Status**: DONE ✅
**Priority**: CRITICAL (User Adoption)

### 🧩 Contexto
La instalación vía `curl | bash` en Debian presentaba 3 fallos de fricción detectados en pruebas reales:
1.  Pérdida de TUI (TTY) sin aviso.
2.  Conflicto de puertos (8000/50051) no verificado.
3.  Corrupción de SQLCipher si se reutilizan volúmenes con llaves nuevas.

### 🎯 Cambios Realizados
1.  **TTY Protection**: Añadido aviso explícito de cómo usar `bash <(curl ...)` si se detecta pérdida de terminal.
2.  **Network Pre-flight**: El instalador ahora audita si los puertos 8000 y 50051 están ocupados e impide el despliegue con un error claro.
3.  **Self-Healing Volumes**: El script detecta si es una `NEW_INSTALLATION` y realiza un `down --volumes` para garantizar que no haya remanentes de bases de datos cifradas con llaves antiguas.

### 📜 Resultado
La instalación ahora es **flawless** en servidores Debian frescos o con instalaciones previas corruptas.

---
*Completed: 2026-03-19 | SRE: Antigravity*

# 🏛️ TICKETS SRE - AEGIS INSTALLER

## [INST-118] Aegis Scrub Utility (The Uninstaller)

**Status**: IN-PROGRESS
**Priority**: HIGH (SRE Operations)

### 🧩 Contexto
Para garantizar que el usuario final pueda realizar una **Fresh Installation** en caso de corrupción o errores de red (puertos ocupados), el sistema Aegis OS requiere una utilidad de limpieza oficial. Actualmente, la desinstalación es manual y propensa a errores (bases de datos de SQLCipher huérfanas).

### 🎯 Objetivos
1.  **Stop everything**: Detener el servicio `systemd` y contenedores.
2.  **Clear Docker Resources**: Borrar volúmenes (especialmente `ank-data` con llaves viejas), redes e imágenes.
3.  **Clean system user**: Eliminar el usuario `aegis` del sistema.
4.  **Filesystem cleanup**: Borrar `/opt/aegis` y logs temporales.

### 📜 Especificaciones SRE
*   **One-Liner Integration**: El script debe ser ejecutable vía `curl | bash`.
*   **Zero-Panic**: Debe manejar errores silenciosamente (ej. si una carpeta ya no existe).
*   **Integridad**: El script debe devolver un código de salida 0 al terminar exitosamente.

---
*Created: 2026-03-19 | SRE: Antigravity*

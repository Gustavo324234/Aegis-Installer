# Changelog
 
## [1.3.2] - 2026-03-12
### Fixed
- **[INST-105] TUI TTY Allocation & Protection**:
    - Forzada la redirección de entrada estándar para `whiptail` mediante `< /dev/tty`.
    - Implementado flag `--no-tui` para forzar el modo texto puro.
    - Agregado mecanismo de **Hard-Fallback**: detección automática de errores de renderizado ANSI con limpieza de pantalla (`clear`) y transición automática a un diálogo CLI estándar (`read -p`).
    - Robustecimiento del `Bootstrapper` para entornos de despliegue remotos con asignación de terminal defectuosa.

## [1.3.1] - 2026-03-12
## [1.3.0] - 2026-03-11
### Added
- **[ANK-2001] Aegis Bootstrapper (TUI)**:
    - Transformación del script de instalación en una experiencia interactiva utilizando `whiptail`.
    - Selección de Perfil de Hardware (Microkernel Cloud vs Monolith Local GPU), inyectando dinámicamente flags de Rust (`--features`).
    - Selección de Perfil de UI (Aegis Shell Web vs Headless), usando *Docker Compose profiles* (`--profile frontend`).
    - Auto-generación dinámica de `AEGIS_FEATURES` en `.env`.

## [1.2.0] - 2026-03-10
### Added
- **[INST-103] Zero-Touch Installer (Auto-Env Generation)**:
    - Eliminado el bloqueo (fail-fast) que impedía la instalación sin archivo `.env` manual.
    - Autogeneración criptográficamente segura de `AEGIS_ROOT_KEY` (vía `openssl rand`) inyectada dinámicamente si el archivo no existe.
    - Aplicación de política Zero-Trust estableciendo permisos `chmod 600` al `.env`.
    - Modernización y claridad del mensaje glorioso final con instrucciones al Server IP para configurar la IA.

## [1.1.0] - 2026-03-09
### Added
- **[INST-102] Self-Healing One-Line Deploy**:
    - Implementado `install_aegis.sh` como orquestador maestro con verificación automática de dependencias (Docker/Git/Curl).
    - Agregada Guardia de Seguridad (Citadel Guard): el despliegue aborta si falta el archivo `.env`.
    - Automatización de clonación/actualización nativa de los 3 repositorios en `/opt/aegis/`.
    - Validación Post-Despliegue: Implementación de Health-Checks que verifican gRPC (Kernel) y HTTP (BFF) antes de finalizar.

## [1.0.0] - 2026-03-06
### Added
- **[INST-101] Aegis Core Containerization**:
    - **Docker Compose**: Se introdujo configuración oficial para orquestar `ank-server` y `aegis-shell` bajo una misma red privada, exponiendo únicamente el puerto `8000` de the Shell hacia el exterior, siguiendo el concepto Zero-Trust.
    - **Aceleración C++ / CUDA**: La imagen del `ank-server` utiliza `nvidia/cuda:12.2.2` delegando compilación por layers y preparando el terreno nativo para llama.cpp y whisper.cpp.
    - **Privilegios Restringidos**: Contenedor del Kernel forzado en SRE isolation a través de la creación y switch a un usuario sin privilegios `aegis` (`useradd aegis`).
    - **Volúmenes y Env**: Configurado el almacenamiento persistente nativo para `/app/users` (bases de datos de enclave) y `/app/models`. Agregado baseline `.env.example`.

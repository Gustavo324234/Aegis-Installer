# Changelog

## [Unreleased]

### Added
- **[INST-29-001] Setup Token Display**:
    - The installer now waits for the Aegis Neural Kernel (ANK) to initialize.
    - Automatically extracts the one-time `setup_token` from ANK logs.
    - Displays a clickable URL with the token for zero-friction first-time administrative setup.
    - Added fallback instructions to use `sudo aegis-token` if the token cannot be retrieved automatically.
- **[INST-29-002] CLI `aegis-token` Utility**:
    - Created a standalone `aegis_token.sh` script to facilitate setup token regeneration.
    - Enables users to trigger manual token regeneration via SSH/CLI if the initial token expires.
    - Automatically checks system status via the BFF API to prevent unauthorized token exposure on already-configured systems.
    - Integrated into the deployment process for automatic installation in `/usr/local/bin/aegis-token`.
- **[INST-31-001] Native Installation Mode**:
    - Added the option to install Aegis OS as a native system daemon, bypassing Docker.
    - Automatic OS detection for Linux, Windows (WSL), and macOS.
    - Implemented `install_native()` flow: downloads pre-compiled binaries and setups local Python environments.
    - Native mode recommended for edge devices and faster startup.
- **[INST-31-002] Unified `aegis` CLI**:
    - Created a unified `aegis` command-line tool to manage the system regardless of installation mode.
    - Commands: `start`, `stop`, `restart`, `status`, `logs`, `dev`, `token`, `update`.
    - Automatically detects the installation mode from `/etc/aegis/mode`.
    - Integrated `aegis-update` for seamless binary updates in native mode.

## [1.5.0] - 2026-03-25
### Added
- **[INST-121] Aegis DevSync — Server-Side Hot-Reload Script (Epic 24)**:
    - Created `aegis_hotreload.sh` — SRE-grade Bash script for selective container reload on the Debian server.
    - Supports `--repo ank|shell|installer|all` and `--force-full` flags for granular reload control.
    - `--repo shell` → `docker restart aegis-shell` (~5s), `--repo ank` → incremental `docker compose build + up -d`.
    - Post-reload health checks: BFF `/health` endpoint (10 retries) + ANK port 50051 availability (120s timeout).
    - On health check failure, prints last 30 lines of container logs and exits non-zero.
    - Timestamped logging `[HH:MM:SS] [INFO|OK|WARN|ERROR]` matching existing SRE script conventions.
    - Idempotent execution — safe to run multiple times consecutively.
    - Installed on server at `/usr/local/bin/aegis_hotreload.sh` with permissions `755`.
    - `shellcheck` → 0 warnings.
- **[INST-120] Aegis DevSync — Windows-to-Server Sync Script (Epic 24)**:
    - Created `aegis_sync.ps1` — PowerShell script for rapid Windows → Debian file synchronization via rsync+SSH.
    - Parameters: `-Repo` (all|ank|shell|installer), `-Server`, `-User`, `-KeyPath`, `-DryRun`.
    - Multi-strategy rsync detection: native PATH → Git Bash → WSL, with actionable error messages if unavailable.
    - Automatic path conversion for WSL (`/mnt/c/...`) and Git Bash (`/c/...`) rsync variants.
    - **Security invariant**: `.env`, `.env.*`, `target/`, `node_modules/`, `.git/`, `users/`, `models/` NEVER transferred.
    - After sync, dispatches `aegis_hotreload.sh --repo <target>` on the server via SSH for automatic reload.
    - `-DryRun` mode shows exactly what would transfer without executing any action.
    - Timestamped colored output matching SRE conventions.

## [1.4.4] - 2026-03-20
### Fixed
- **[INST-119] Fix Container Name Conflict in GPU Profile**:
    - Resolved critical orchestration failure where `ank-server` and `ank-server-gpu` services competed for the same `aegis-ank` container name.
    - Added `profiles: ["cpu"]` to the standard `ank-server` service in `docker-compose.yml`.
    - Updated `install_aegis.sh` to explicitly activate the `cpu` profile when GPU hardware is not selected (`HW_PROFILE != 3`).
    - Ensured mutual exclusivity between CPU and GPU containers, preventing "container name already in use" errors during deployment.

### Security
- **[INST-SEC-125] Implicit mTLS mode for Bootstrap**:
  - Added `AEGIS_MTLS_STRICT=false` to the generated `.env` file during the `security_guard()` phase.
  - This prevents the Aegis-ANK Kernel from entering a restart loop when running without certificates (default behavior in new installations).
  - Added logic to inject the variable into existing `.env` files if missing, ensuring backward compatibility.
- **[INST-SEC-122] Strict diagnostics mode**:
  - Implemented `set -euo pipefail` in `aegis_diag.sh` for reliable system diagnostics.
  - Hardened command execution with proper error handling and fallback messages.
- **[INST-SEC-123] Destructive action safeguards**:
  - Added explicit 'yes' confirmation prompt to `uninstall_aegis.sh` to prevent accidental data loss.
  - Implemented `--force` and `--no-confirm` flags for automated environments.

### Added
- **[GOV-108] Smoke Test Suite — Full Stack E2E Verification**:
    - Created `smoke_test.sh` for post-installation validation.
    - Implemented 7 non-destructive checks: Docker status, ANK/Shell container state, gRPC port (50051) connectivity, BFF API health, UI accessibility, and environment variable integrity.
    - Added comprehensive "Smoke Test" section to `README.md` with usage instructions and check details.
    - Verified with `shellcheck` (0 warnings) and `bash -n` compliance.

- **[ANK-INST-003] Redesign: Zero-friction onboarding — State-based setup:**
    - Removed `install_token` display logic from the `print_success` screen.
    - Simplified the bootstrapper by eliminating the need to capture or inject installation tokens.
    - Fully decoupled the Installer from the Kernel's internal initialization state.
- **[INST-113] UX Progress Feedback in TUI Mode**:
    - Reemplazados diálogos silenciosos bloqueantes y agregadas barras de estado (`infobox`) detalladas en las fases críticas (Dependencies, Workspace, Orchestration).
    - Mejorada interactividad y visibilidad en tiempo real para procesos lentos (`apt-get`, `git clone`, `docker pull`).
    - Eliminado el bloqueo interactivo (`msgbox`) tras la fase de clonación de repositorio, asegurando un progreso ininterrumpido.
- **[INST-112] Smart Profiles Bootstrapper (OOM-Safe)**:
    - Añadidas etiquetas `image` en `docker-compose.yml` apuntando a `ghcr.io/gustavo324234/aegis-ank:latest` y `aegis-shell:latest`.
    - Refactorizado el menú de `install_aegis.sh` para incluir 3 perfiles de orquestación (Cloud/Edge, Local Monolith, Hybrid GPU).
    - Implementado Pre-flight RAM Check: Advertencia interactiva OOMKill (`dialog --yesno`) si RAM < 2000MB y se elige compilación local.
    - Añadida lógica dinámica a `orchestrate()` para elegir entre `pull` o `build` dependiendo del perfil.

### Fixed
- Declare SERVER_IP as global variable to prevent unbound error in print_success() [INST-29-003]
- **[INST-116] Capture ANK install token and inject into BFF**:
    - Implementada captura automatizada del `INSTALL TOKEN` generado por el Kernel al inicio (extrayéndolo de los logs del contenedor `ank-server`).
    - Inyectado dinámicamente el token en el archivo `.env` bajo la variable `AEGIS_INSTALL_TOKEN`.
    - Agregado reinicio automático del contenedor `aegis-shell` en la fase de orquestación para asegurar que el BFF cargue el token inmediatamente.
    - Sincronizado `docker-compose.yml` para propagar `${AEGIS_INSTALL_TOKEN}` como variable de entorno al servicio de la Shell.
- **[INST-115] LAN IP Detection in Success Screen**:
    - Reemplazada la llamada a `ifconfig.me` por una detección local robusta usando `ip route get`.
    - Implementado fallback escalonado: `ip route` → `hostname -I` → `localhost`.
    - Mejora de privacidad eliminando la exposición de la IP pública en la terminal y soporte para instalaciones offline.
- **[INST-114] Dialog File Descriptor Pattern on Debian**:
    - Añadido `set +e` / `set -e` alrededor de comandos `dialog` para prevenir fallos por `set -euo pipefail` (errexit) al recibir códigos de salida distintos de cero de `dialog`.
    - Asignación de valores por defecto mediante Parameter Expansion (`${VAR:-1}`) para `HW_PROFILE` y `UI_PROFILE` previniendo errores por variables no definidas.
    - Reemplazado el patrón `exec 3>&1 / 2>&1 1>&3` por la variante portátil `3>&1 1>&2 2>&3` para garantizar la captura del estado de `dialog` en Debian.
    - Simplificado el `OOMKill Warning` para utilizar `msgbox` con fallback automático al perfil Cloud/Edge evitando bucles problemáticos.
- **[INST-113] ShellCheck Warnings Resolution**:
    - Solucionado SC2129 empleando un bloque bash para agrupación de redirecciones stdout/stderr.
    - Resuelto SC2086 mediante el uso de bash arrays fuertes para variables con comillas simples (args de Docker Compose).
- **[INST-112] Smart Profiles + Systemd Hardening Fusion**:
    - Fixed `aegis` user missing in docker group to ensure valid volume permissions.
    - Updated `aegis.service` to `ProtectSystem=full` and added Docker socket to `ReadWritePaths`.
    - Removed `sudo -u` wrappers in `orchestrate()` and `setup_workspace()` when already running as unprivileged user via systemd.
    - Used `:?` operator in `docker-compose.yml` to remove `AEGIS_ROOT_KEY` fallback, ensuring a visible error if unset.

## [1.4.3] - 2026-03-15
### Fixed
- **[INST-109] Zero-Touch Log Permission Fix**:
    - Garantizada la ejecución exitosa del comando oficial de una sola línea (`curl ... | sudo bash`) mediante el saneamiento agresivo de permisos en `/tmp/aegis_install.log`.
    - Implementada destrucción y recreación del archivo de log con permisos universales (`666`) al inicio del script para evitar errores de `Permission denied`.
    - Silenciadas las salidas de error de `rm` y `chmod` para mantener la integridad visual del banner ASCII.
    - Asegurada la consistencia del logging delegando todas las operaciones a la variable `$LOG_FILE`.

## [1.4.2] - 2026-03-12
### Added
- **[INST-108] TUI Buffer Cleanup & Ghosting Fix**:
    - Implementada redirección masiva de logs a `/tmp/aegis_install.log` para silenciar comandos ruidosos (`apt`, `git`, `docker`) durante la operación del TUI.
    - Agregado flag mandatory `--clear` a todas las invocaciones de `dialog` para prevenir el apilamiento de artefactos visuales.
    - Añadidas limpiezas de pantalla de transición (`clear`) entre bloques lógicos del instalador.
    - Refactorizadas las funciones de log (`log`, `success`, `warn`) para operar en modo silencioso cuando el TUI está activo, manteniendo la trazabilidad en el archivo de log.

## [1.4.1] - 2026-03-12
### Fixed
- **[INST-107] ASCII Banner Correction**:
    - Corregido typo en el banner (de "AEGI SO" a "AEGIS OS").
    - Optimizado el ancho del arte ASCII para máxima compatibilidad con TTYs estrechos (60 col).
    - Eliminados espacios de padding inconsistentes que rompían el renderizado en SSH.

## [1.4.0] - 2026-03-12
### Changed
- **[INST-106] Professional Bootstrapper Redesign**:
    - Migración completa de `whiptail` a `dialog` para una gestión robusta del TTY.
    - Implementada arquitectura "Zero-Error" con redirección de descriptores de archivo (`exec 3>&1`).
    - Añadido Banner ASCII profesional y estética Linux de grado servidor.
    - Implementado sistema de **Pre-flight Audit** (CPU, RAM, Docker, GPU) con reporte visual.
    - Agregadas barras de progreso (`gauge`) para la sincronización de repositorios.
    - Soporte nativo para Modo Dual (Interactivo vs Scripted/Headless).

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

### Added
- **[INST-SEC-121] Shell Strict Mode Verification:**
  - Added `test_scripts.py` to verify that all deployment and uninstallation scripts (`install_aegis.sh`, `uninstall_aegis.sh`) enforce `set -euo pipefail` to ensure atomic and fail-fast operations.

## [v1.4.7] - 2026-04-01
### Fixed
- Fixed infinite `y/y/y` loop in `uninstall_aegis.sh` by enforcing non-interactive behavior in `deluser` and `groupdel`.
- Standardized and documented `sudo bash -c "$(curl ...)"` as the official installation method to prevent file descriptor errors (`/dev/fd/63`) and provide reliable TTY access for interactive menus.

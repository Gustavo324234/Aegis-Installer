# Changelog

## [Unreleased]
### Added
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
- **[INST-114] Dialog File Descriptor Pattern on Debian**:
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

### Security
- **[INST-STB-019] Unprivileged Service Account & Systemd Hardening**:
    - Added `create_aegis_user()` phase (phase 6): creates a dedicated `aegis` system user (`--system --no-create-home --shell /sbin/nologin`) idempotently via `id -u` check before calling `useradd`.
    - Added `install_systemd_service()` phase (phase 7): writes `/etc/systemd/system/aegis.service` with `User=aegis`, `NoNewPrivileges=true`, `ProtectSystem=strict`, `ProtectHome=true`, and `ReadWritePaths=/opt/aegis /tmp`; gracefully degrades if systemd is not running.
    - Fixed `set -eo pipefail` → `set -euo pipefail` to enforce strict unbound-variable detection (SRE Law 2).
    - Initialized `SELECTED_FEATURES` and `SELECTED_UI` at global scope to satisfy `set -u` in scripted/headless mode.
    - Resolved ShellCheck SC2155 violations (declare-then-assign) in `check_system_requirements` and `security_guard`.
    - Removed unused variables `FORCE_ROOT_ORCHESTRATION` and `MAGENTA` (SC2034).

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

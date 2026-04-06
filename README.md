# Aegis OS

[![CI](https://github.com/Gustavo324234/Aegis-Installer/actions/workflows/pr_check.yml/badge.svg)](https://github.com/Gustavo324234/Aegis-Installer/actions/workflows/pr_check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![SRE: Zero-Panic](https://img.shields.io/badge/SRE-Zero--Panic-brightgreen.svg)]()

Aegis OS is an **open source cognitive operating system**. It runs LLMs — local or cloud — as deterministic execution units under strict SRE policies, with cryptographic multi-tenant isolation and a gRPC-first architecture.

This repository is the **installer and orchestrator**. It deploys the full Aegis stack (kernel + shell) using two modes: **Native Binary** (using `aegis-supervisor`) or **Docker Containers**.

---

## 🚀 Deployment Modes

### 1. 🖥️ Native Mode (Recommended for Desktop)
Aegis runs directly on your OS as a background service managed by **aegis-supervisor**. This mode is ideal for local development and general desktop use on Windows and macOS, as it doesn't require virtualization or WSL2.

### 2. 🐋 Docker Mode (Recommended for Servers)
Aegis runs inside lightweight containers. This mode is the standard for Linux servers and production environments, ensuring total isolation and reproducible deployments via Docker Compose.

---

## ⚡ Quickstart

### Linux (Nativo o Docker)
```bash
sudo bash -c "$(curl -sSL https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/install_aegis.sh)"
```
*The installer will ask you to choose between Native and Docker.*

### Windows (Nativo)
1. Download the latest `aegis-installer.exe` (or run via PowerShell as Administrator):
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/install_aegis.ps1'))
```
*Native mode on Windows registers Aegis as an official Windows Service.*

### macOS (Nativo - Intel & Apple Silicon)
```bash
bash -c "$(curl -sSL https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/install_aegis.sh)"
```
*Registers Aegis as a `LaunchAgent` using `launchd`.*

---

## 🛠️ The `aegis` CLI

Once installed, you can manage the entire OS with the unified `aegis` command:

| Command | Action |
|---|---|
| `aegis start` | Starts all services (Kernel + Shell) |
| `aegis stop` | Stops all services safely (Zero-Panic flush) |
| `aegis status` | Shows CPU/VRAM usage and service health |
| `aegis logs` | Tails both kernel and frontend logs |
| `aegis dev` | Starts in development mode with Hot-Reload |
| `aegis token` | Generates a new setup token if needed |
| `aegis update` | Pulls the latest version from GitHub |

---

## 📋 What the installer does (Phase Breakdown)

`install_aegis.sh` runs in 10 sequential phases:

```
Phase 1  check_system_requirements()
         Verifies CPU cores, RAM (warns if < 2GB), GPU (nvidia-smi)

Phase 2  select_deployment_mode()  [TUI mode only]
         Target: Native vs Docker vs Cloud-Hybrid

Phase 3  install_dependencies()
         Nativo: Rust toolchain, Python 3.10+, git
         Docker: Docker Engine (if missing)

Phase 4  setup_workspace()
         git clone/pull: Aegis-ANK, Aegis-Shell into /opt/aegis/

Phase 5  build_orchestrator()
         Compiles aegis-supervisor (Rust) for the host architecture

Phase 6  security_guard()
         Generates AEGIS_ROOT_KEY (openssl rand -hex 32)
         Writes .env with chmod 600

Phase 7  register_as_service()
         Linux: systemd unit installation
         Windows: registers Windows Service / Task Scheduler
         macOS: generates launchd plist

Phase 8  orchestrate()
         Nativo: starts aegis-supervisor
         Docker: docker compose up -d

Phase 9  print_success()
         Displays Shell URL (http://localhost:8000)
```

All phases are logged to `/tmp/aegis_install.log`.

---

## Repositories

| Repo | Role |
|---|---|
| **[Aegis-Installer](https://github.com/Gustavo324234/Aegis-Installer)** | This repo — deploys the full stack |
| **[Aegis-ANK](https://github.com/Gustavo324234/Aegis-ANK)** | Neural Kernel (Rust/Tokio/gRPC) — can be used standalone |
| **[Aegis-Shell](https://github.com/Gustavo324234/Aegis-Shell)** | Reference UI + BFF (React + FastAPI) |

> **Aegis-ANK is a standalone component.** You can run just the kernel and connect your own shell, CLI, or any gRPC client to it. See the [ANK documentation](https://github.com/Gustavo324234/Aegis-ANK) for details.

---

## Table of contents

1. [Quickstart — Linux](#1-quickstart--linux)
2. [Quickstart — Windows (WSL2)](#2-quickstart--windows-wsl2)
3. [What the installer does](#3-what-the-installer-does)
4. [Configuration](#4-configuration)
5. [Deployment profiles](#5-deployment-profiles)
6. [Managing tenants](#6-managing-tenants)
7. [Verifying the deployment](#7-verifying-the-deployment)
8. [Updating](#8-updating)
9. [Architecture](#9-architecture)
10. [Contributing](#10-contributing)
11. [Roadmap](#11-roadmap)
12. [Smoke Test](#12-smoke-test)

---


## 4. Configuration

The installer generates `.env` automatically. To customize before deploying, copy the example and edit:

```bash
cd /opt/aegis/Aegis-Installer
cp .env.example .env
nano .env
```

| Variable | Required | Description |
|---|---|---|
| `AEGIS_ROOT_KEY` | **Yes** | Master key for all SQLCipher tenant enclaves. Auto-generated by the installer. Never use a default value — the system refuses to start if unset. |
| `AEGIS_WHISPER_MODEL` | No | Filename of the Whisper GGUF model in `./models/`. Required only if using Siren voice protocol. |
| `AEGIS_FEATURES` | No | Cargo feature flags for ANK. Set `full_local` to enable GPU-accelerated local inference. |
| `AEGIS_ALLOWED_ORIGINS` | No | Comma-separated list of allowed CORS origins for the Shell BFF. Defaults to `http://localhost:8000`. |

### Adding a local LLM model

Place your GGUF model file in `/opt/aegis/Aegis-Installer/models/`:

```bash
wget https://huggingface.co/TheBloke/Mistral-7B-v0.1-GGUF/resolve/main/mistral-7b-v0.1.Q4_K_M.gguf \
  -O /opt/aegis/Aegis-Installer/models/mistral-7b.gguf
```

Then configure the model from the Engine Setup Wizard in the Shell UI.

---

## 5. Deployment profiles

### Full stack (default)

Deploys both the kernel and the shell UI:

```bash
docker compose --profile frontend up -d
```

Exposes:
- `http://localhost:8000` — Aegis Shell UI
- `localhost:50051` — ANK gRPC (internal, not exposed externally)

### Headless kernel only

Deploys only ANK without the shell:

```bash
docker compose up -d ank-server
```

See [Aegis-ANK](https://github.com/Gustavo324234/Aegis-ANK) for how to connect a custom gRPC client.

### GPU vs CPU

Set `AEGIS_FEATURES=full_local` in `.env` to enable GPU-accelerated inference via llama-cpp2. Requires NVIDIA drivers and CUDA toolkit on the host.

---

## 6. Managing tenants

```bash
# Create the master admin (first run only — localhost only)
docker exec -it aegis-ank aegis admin init-admin <username>

# Create a new tenant
docker exec -it aegis-ank aegis admin create-tenant <username>
# → Returns: tenant_id, temporary_passphrase, assigned_port

# Reset a tenant's passphrase
docker exec -it aegis-ank aegis admin reset-password <tenant_id>
```

Each tenant gets a cryptographically isolated SQLCipher enclave. No admin can read another tenant's data.

---

## 7. Verifying the deployment

```bash
# BFF online
curl -s http://localhost:8000/health
# → {"status": "Aegis BFF Online", "version": "0.1.0"}

# Kernel state
curl -s http://localhost:8000/api/system/state
# → {"state": "STATE_INITIALIZING"}  (before first admin setup)
# → {"state": "STATE_OPERATIONAL"}   (after admin initialized)

# Check running containers
docker ps

# Tail kernel logs
docker logs -f aegis-ank
```

---

## 8. Updating

```bash
cd /opt/aegis/Aegis-Installer
git pull origin main
sudo docker compose --profile frontend up -d --build
```

---

## 9. Uninstall — Scrub Mode

To completely remove Aegis OS (including all tenant databases, models, users, and system services), run the official uninstaller:

```bash
sudo bash <(curl -sSL https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/uninstall_aegis.sh)
```

> [!CAUTION]
> **Data Loss**: This action is irreversible. It wipes `/opt/aegis`, all Docker volumes (SQLCipher enclaves), and the `aegis` system user.

---

## 10. Developer Workflow (Sync & Reset)

For developers working between Windows and a remote Debian server, Aegis OS provides a specialized **DevSync Engine**. This tool allows for hot-reloading code and performing full system resets (Zero-Panic) with a single command.

- **Sync Tool:** `.\aegis_sync.ps1`
- **Full Guide:** See [DEVELOPER_WORKFLOW.md](DEVELOPER_WORKFLOW.md)

---

## 11. Architecture

```
Aegis-Installer (this repo)
        │
        │  docker compose
        ├──────────────────────────────────┐
        ▼                                  ▼
Aegis-ANK (port 50051)          Aegis-Shell (port 8000)
Rust / Tokio / gRPC             FastAPI BFF + React UI
        │                                  │
        │◄─── gRPC Citadel Protocol ───────┤
        │                                  │
        └── SQLCipher enclaves (per tenant)
        └── Wasm plugins (Ed25519-signed)
        └── llama-cpp2 / OpenAI API
```

**Network:** ANK's gRPC port (`50051`) is internal only — not exposed to the host. Only port `8000` is exposed publicly.

**Volumes:**
- `./users/` — per-tenant jailed workspaces (mounted into ANK)
- `./models/` — local GGUF model files (mounted into ANK)

**Security:**
- `aegis` system user (no login shell) runs the containers
- Systemd unit hardened: `NoNewPrivileges=true`, `ProtectSystem=full`, `ProtectHome=true`
- `AEGIS_ROOT_KEY` auto-generated, never has a default value

---

## 10. Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full SRE standards and commit conventions.

All changes to `install_aegis.sh` must pass `shellcheck` locally before opening a PR:

```bash
shellcheck install_aegis.sh
```

---

## 11. Roadmap

Stable in v2.0.0:

- One-command deploy on Debian/Ubuntu with interactive TUI
- Headless `--no-tui` mode for CI/CD
- GPU pre-flight check (nvidia-smi)
- Auto-generated `AEGIS_ROOT_KEY` — hard fail if unset
- Self-healing Docker install
- WSL2 support (documented)
- Unprivileged `aegis` system user + systemd hardening
- Smart deployment profiles (Cloud/Edge, Local Monolith, Hybrid GPU)

Tracked for post-MVP:

| Feature | Status |
|---|---|
| Support for AMD ROCm GPU | planned |
| Automated upgrade script | planned |
| ARM64 / Raspberry Pi support | planned |

---

## 12. Smoke Test

After installation, you can verify that the full Aegis stack is operational by running the Smoke Test suite. This script performs 7 non-destructive checks to ensure that all services are correctly connected and responding.

```bash
cd /opt/aegis/Aegis-Installer
bash smoke_test.sh
```

**Checks performed:**
- **Docker daemon**: Verifies that the Docker engine is running.
- **ANK Container**: Checks if the Neural Kernel container is active.
- **Shell Container**: Checks if the UI + BFF container is active.
- **gRPC Connectivity**: Validates that port 50051 is open and accessible.
- **BFF Status**: Requests `/api/status` to ensure the backend is initialized.
- **UI Accessibility**: Verifies that the Web UI is serving HTTP 200.
- **Root Secrecy**: Ensures `AEGIS_ROOT_KEY` is correctly defined in `.env`.

This script is ideal for post-deployment verification and CI pipelines.

---

*Orchestrates: [Aegis-ANK](https://github.com/Gustavo324234/Aegis-ANK) · [Aegis-Shell](https://github.com/Gustavo324234/Aegis-Shell)*

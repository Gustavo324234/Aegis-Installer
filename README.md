# Aegis OS

[![CI](https://github.com/Gustavo324234/Aegis-Installer/actions/workflows/pr_check.yml/badge.svg)](https://github.com/Gustavo324234/Aegis-Installer/actions/workflows/pr_check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![SRE: Zero-Panic](https://img.shields.io/badge/SRE-Zero--Panic-brightgreen.svg)]()

Aegis OS is an **open source cognitive operating system**. It runs LLMs — local or cloud — as deterministic execution units under strict SRE policies, with cryptographic multi-tenant isolation and a gRPC-first architecture.

This repository is the **installer and orchestrator**. It deploys the full Aegis stack (kernel + shell) via Docker Compose with a single command.

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

---

## 1. Quickstart — Linux

Tested on Debian 11+, Ubuntu 20.04+. Requires `sudo`.

```bash
curl -sSL https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/install_aegis.sh | sudo bash
```

The script installs all dependencies (Docker, Docker Compose, git), clones the repos, generates secrets, and starts the stack. When it finishes:

```
✅ Aegis OS deployed successfully
   Shell: http://<your-ip>:8000
```

Open the URL in your browser and follow the Engine Setup Wizard to configure your LLM (cloud API key or local GGUF model).

### Headless / CI mode

If you are running in a non-interactive environment (SSH without TTY, CI pipeline):

```bash
sudo ./install_aegis.sh --no-tui
```

---

## 2. Quickstart — Windows (WSL2)

> **Important:** Always clone and run Aegis inside the Linux filesystem (`~/`), not inside `/mnt/c/`. Docker volume mounts do not work correctly on the Windows filesystem from WSL2.

### Step 1 — Install WSL2

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

Restart your machine. This installs WSL2 with Ubuntu by default.

### Step 2 — Install Docker Desktop

Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/). During setup, enable **"Use WSL2 based engine"**. After installation, go to `Settings → Resources → WSL Integration` and enable integration for your Ubuntu distro.

### Step 3 — Run the installer inside WSL2

Open your Ubuntu terminal (not PowerShell) and run:

```bash
# Make sure you are in the Linux home directory
cd ~

# Run the installer
curl -sSL https://raw.githubusercontent.com/Gustavo324234/Aegis-Installer/main/install_aegis.sh | sudo bash
```

Then open `http://localhost:8000` in your Windows browser.

### Common WSL2 pitfalls

| Problem | Cause | Fix |
|---|---|---|
| `permission denied` on Docker | User not in docker group | Run `sudo usermod -aG docker $USER` then restart WSL |
| Volumes not mounting | Cloned inside `/mnt/c/` | Re-clone under `~/` |
| Port not accessible in browser | Docker Desktop WSL integration off | Enable in Docker Desktop settings |

---

## 3. What the installer does

`install_aegis.sh` runs in 7 sequential phases:

```
Phase 1  check_system_requirements()
         Verifies CPU cores, RAM (warns if < 2GB), Docker, NVIDIA GPU

Phase 2  install_dependencies()
         apt-get: git, curl, dialog, openssl
         Docker Engine (auto-installs if missing)

Phase 3  configure_profiles()  [TUI mode only]
         Select hardware profile: GPU local vs CPU-only cloud
         Select UI profile: full stack vs headless kernel only

Phase 4  setup_workspace()
         git clone/pull: Aegis-ANK, Aegis-Shell into /opt/aegis/

Phase 5  security_guard()
         Generates AEGIS_ROOT_KEY via openssl rand -hex 32
         Writes .env with chmod 600

Phase 6  orchestrate()
         docker compose --profile frontend up -d --build

Phase 7  print_success()
         Displays public IP and Shell URL
```

All phases are logged to `/tmp/aegis_install.log`.

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
| `AEGIS_ROOT_KEY` | **Yes** | Master key for all SQLCipher tenant enclaves. Auto-generated by the installer. Never use the default value. |
| `AEGIS_WHISPER_MODEL` | No | Filename of the Whisper GGUF model in `./models/`. Required only if using Siren voice protocol. |
| `AEGIS_FEATURES` | No | Cargo feature flags for ANK. Set `full_local` to enable GPU-accelerated local inference. |

### Adding a local LLM model

Place your GGUF model file in `/opt/aegis/Aegis-Installer/models/`:

```bash
# Example: download Mistral 7B GGUF
wget https://huggingface.co/TheBloke/Mistral-7B-v0.1-GGUF/resolve/main/mistral-7b-v0.1.Q4_K_M.gguf \
  -O /opt/aegis/Aegis-Installer/models/mistral-7b.gguf
```

Then configure the model from the Engine Setup Wizard in the Shell UI, or directly via the ANK CLI:

```bash
docker exec -it aegis-ank aegis admin configure-engine \
  --model /app/models/mistral-7b.gguf
```

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

Deploys only ANK without the shell. Use this if you want to connect your own client:

```bash
docker compose up -d ank-server
```

Exposes:
- `localhost:50051` — ANK gRPC (accessible to your client)

See [Aegis-ANK](https://github.com/Gustavo324234/Aegis-ANK) for how to connect a custom gRPC client.

### GPU vs CPU

Set `AEGIS_FEATURES=full_local` in `.env` to enable GPU-accelerated inference via llama-cpp2. Requires NVIDIA drivers and CUDA toolkit on the host. Without this flag, ANK runs in cloud-API-only mode (no local model inference).

---

## 6. Managing tenants

After deployment, use the ANK admin CLI to manage users:

```bash
# Create the master admin (first run only)
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

# Kernel operational
curl -s http://localhost:8000/api/system/state
# → {"state": "STATE_OPERATIONAL"}

# Check running containers
docker ps
# → aegis-ank and aegis-shell should show "Up"

# Tail kernel logs
docker logs -f aegis-ank
```

---

## 8. Updating

```bash
cd /opt/aegis/Aegis-Installer

# Pull latest changes
git pull origin main

# Rebuild and restart
sudo docker compose --profile frontend up -d --build
```

---

## 9. Architecture

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
        └── SQLCipher enclaves             └── serves browser
        └── Wasm plugins                  └── WebSocket bridge
        └── llama-cpp2 / OpenAI API
```

**Network:** Both services run on the `aegis_net` Docker bridge network. ANK's gRPC port (`50051`) is internal only — not exposed to the host. Only the Shell port (`8000`) is exposed publicly.

**Volumes:**
- `./users/` — per-tenant jailed workspaces (mounted into ANK)
- `./models/` — local GGUF model files (mounted into ANK)

---

## 10. Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full SRE standards and commit conventions.

For the Installer specifically: all changes to `install_aegis.sh` must pass `shellcheck` locally before opening a PR. The CI runs `shellcheck` automatically on every PR.

```bash
shellcheck install_aegis.sh
```

Changes to `docker-compose.yml` service names or network topology require an RFC issue first — they affect the `ANK_TARGET` variable in Aegis-Shell and any external clients depending on service discovery.

---

## 11. Roadmap

Stable in v2.0.0:

- One-line deploy on Debian/Ubuntu
- TUI interactive installer (dialog)
- Headless `--no-tui` mode for CI/CD
- GPU pre-flight check (nvidia-smi)
- Auto-generated `AEGIS_ROOT_KEY`
- Self-healing Docker install
- WSL2 support (documented)

Tracked for post-MVP:

| Feature | Status | Ticket |
|---|---|---|
| Unprivileged `aegis` system user + systemd hardening | `planned` | INST-STB-019 |
| Hard fail on missing `AEGIS_ROOT_KEY` (remove default fallback) | `planned` | ANK-STB-020 |
| Support for AMD ROCm GPU | `planned` | — |
| Automated upgrade script | `planned` | — |

---

*Orchestrates: [Aegis-ANK](https://github.com/Gustavo324234/Aegis-ANK) · [Aegis-Shell](https://github.com/Gustavo324234/Aegis-Shell)*

# Aegis OS — Developer Workflow (Sync & Reset)

This document outlines the specialized toolchain for synchronizing local development code from Windows to the Aegis Debian server.

## 1. Prerequisites
- **WSL (Ubuntu)** installed on Windows.
- **rsync** installed in WSL (`sudo apt install rsync`).
- **SSH Key** configured between Windows and the Debian server.
- **Node.js** installed on Windows (for UI builds).

## 2. Aegis DevSync Toolchain

The core tool is `aegis_sync.ps1`, located in `Aegis-Installer/`.

### Basic Synchronization
Syncs your local changes to the server and triggers a hot-reload of the affected containers.

```powershell
# Sync everything (Kernel, Shell, Installer)
.\aegis_sync.ps1

# Sync only the UI/BFF (Fast)
.\aegis_sync.ps1 -Repo shell

# Sync only the Kernel (Triggers Rust recompilation on server)
.\aegis_sync.ps1 -Repo ank
```

### System Reset (Zero-Panic / Tabula Rasa)
Wipes all tenant databases, local models, and Docker volumes. Moves the system back to `STATE_INITIALIZING`.

```powershell
# Full reset to zero state
.\aegis_sync.ps1 -ResetSystem
```

## 3. Deployment Logic

### The Hot-Reload Engine
The server-side component is `/usr/local/bin/aegis_hotreload.sh`.
- **Shell:** Uses `docker cp` to inject BFF code and UI `dist` folder into the running container, then restarts it.
- **ANK:** Compiles the Rust server inside an Ubuntu container (for glibc compatibility) and replaces the binary.
- **Reset:** Performs `docker compose down -v`, clears `users/` and `models/`, and restarts the stack with `cpu` and `frontend` profiles.

### Sync Version Tracking
Each synchronization generates a unique marker (e.g., `DevSync-20260325-1521`).
- **Backend:** Exposed via `GET /api/system/sync_version`.
- **Frontend:** Displayed in the Login screen footer to verify successful deployment.

## 4. Troubleshooting

### Permission Denied on Server
If file operations fail on the server, ensure `aegis_hotreload.sh` has `sudo` permissions or that the `diego` user is in the `docker` group.

### Port 50051 not available
The ANK port is **internal only**. If you need to check health from the host, use:
```bash
docker exec aegis-ank nc -z localhost 50051
```
(Or check the logs for "ANK Initialized").

### UI changes not showing
1. Run `npm run build` in `Aegis-Shell/ui/` on Windows.
2. Run `.\aegis_sync.ps1 -Repo shell`.
3. Verify the "Sync Version" in the footer matches your last execution.

---
*Created on: 2026-03-25 | Ref: Ticket INST-120/121*

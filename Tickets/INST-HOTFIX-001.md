# [INST-HOTFIX-001] Critical: Fix Orchestration Failure (INST-116 Implementation + docker-compose Fix)

**Epic:** HOTFIX
**Repo:** Aegis-Installer
**Files:** `install_aegis.sh`, `docker-compose.yml`
**Priority:** P0 — CRITICAL (blocks installation)
**Status:** TODO
**Assigned:** DevOps Engineer (Claude Code / OpenCode)

---

## Context

Installation fails at orchestration phase with:
```
CRITICAL ERROR
Orchestration failed. Check /tmp/aegis_install.log
```

Root causes:
1. **INST-116 marked DONE but never implemented** — install token capture logic is missing
2. **`.env` generation incomplete** — missing `AEGIS_ALLOWED_ORIGINS`
3. **docker-compose.yml conflict** — `aegis-shell` depends on `ank-server`, but there are TWO ANK services (base + gpu profile)

---

## Required Changes

### 1. `install_aegis.sh` — Fix `.env` generation in `security_guard()`

**Current (línea 195-204):**
```bash
if [ ! -f "$ENV_PATH" ]; then
    local root_key
    root_key=$(openssl rand -hex 32)
    cat <<EOT > "$ENV_PATH"
AEGIS_ROOT_KEY=$root_key
ANK_TARGET=ank-server:50051
AEGIS_FEATURES=$SELECTED_FEATURES
EOT
    chmod 600 "$ENV_PATH"
    NEW_INSTALLATION=true
    success "Zero-Touch: Root cryptographic key secured."
```

**Fix:**
```bash
if [ ! -f "$ENV_PATH" ]; then
    local root_key
    root_key=$(openssl rand -hex 32)
    cat <<EOT > "$ENV_PATH"
AEGIS_ROOT_KEY=$root_key
ANK_TARGET=ank-server:50051
AEGIS_FEATURES=$SELECTED_FEATURES
AEGIS_WHISPER_MODEL=ggml-base.bin
AEGIS_ALLOWED_ORIGINS=http://localhost:8000
EOT
    chmod 600 "$ENV_PATH"
    NEW_INSTALLATION=true
    success "Zero-Touch: Root cryptographic key secured."
```

### 2. `install_aegis.sh` — Implement INST-116 token capture in `orchestrate()`

**Add AFTER línea 297** (después de `"${compose_cmd[@]}" "${profile_flags[@]}" up -d`):

```bash
    # === INST-116: Capture ANK install token ===
    log "Waiting for ANK to generate install token..."
    local max_wait=30
    local waited=0
    local install_token=""
    local ank_service="ank-server"

    # If GPU profile, the container is still named 'aegis-ank' but service is 'ank-server-gpu'
    if [ "$HW_PROFILE" = "3" ]; then
        ank_service="ank-server-gpu"
    fi

    while [ "$waited" -lt "$max_wait" ]; do
        install_token=$("${compose_cmd[@]}" logs "$ank_service" 2>/dev/null \
            | grep "INSTALL TOKEN" \
            | awk -F'): ' '{print $NF}' \
            | tr -d ' \r\n' \
            | head -n1)

        if [ -n "$install_token" ]; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
    done

    if [ -n "$install_token" ]; then
        # Remove old token if exists, write new one
        sed -i '/^AEGIS_INSTALL_TOKEN=/d' "$ENV_PATH"
        echo "AEGIS_INSTALL_TOKEN=$install_token" >> "$ENV_PATH"
        success "Install token captured and saved to .env"

        # Restart shell container to pick up the new env var (only if frontend profile active)
        if [ "$SELECTED_UI" = "web" ]; then
            "${compose_cmd[@]}" "${profile_flags[@]}" restart aegis-shell >> "$LOG_FILE" 2>&1
            success "Shell restarted with install token."
        fi
    else
        warn "Could not capture install token after ${max_wait}s. Admin setup may require manual token entry."
    fi
```

### 3. `docker-compose.yml` — Fix service dependencies

**Current problema:**
- `aegis-shell` tiene `depends_on: - ank-server`
- Pero si GPU profile está activo, el servicio real es `ank-server-gpu`
- Esto causa que Compose no resuelva las dependencias correctamente

**Fix — Cambiar `depends_on` a condición dinámica basada en profiles:**

```yaml
  aegis-shell:
    image: ghcr.io/gustavo324234/aegis-shell:latest
    build:
      context: ../Aegis-Shell
      dockerfile: Dockerfile
    container_name: aegis-shell
    profiles: ["frontend"]
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - ANK_TARGET=ank-server:50051
      - AEGIS_INSTALL_TOKEN=${AEGIS_INSTALL_TOKEN:-}
    ports:
      - "8000:8000"
    # Remove hard dependency — rely on network availability instead
    # depends_on:
    #   - ank-server
    networks:
      - aegis_net
```

**Nota:** Eliminamos `depends_on` porque:
- Docker Compose no soporta `depends_on` condicional por profiles
- ANK y Shell se comunican via network (`aegis_net`), no necesitan start order estricto
- BFF tiene retry logic en el cliente gRPC

### 4. `docker-compose.yml` — Add missing env var to shell

Ya está en INST-116, pero verificar que esté:

```yaml
environment:
  - ANK_TARGET=ank-server:50051
  - AEGIS_INSTALL_TOKEN=${AEGIS_INSTALL_TOKEN:-}
```

---

## Acceptance Criteria

- [ ] `install_aegis.sh` genera `.env` con todas las variables necesarias:
  - `AEGIS_ROOT_KEY`
  - `ANK_TARGET`
  - `AEGIS_FEATURES`
  - `AEGIS_WHISPER_MODEL`
  - `AEGIS_ALLOWED_ORIGINS`
- [ ] Token de instalación se captura correctamente después de `docker compose up -d`
- [ ] `.env` contiene `AEGIS_INSTALL_TOKEN=<token>` después de la instalación
- [ ] `aegis-shell` se reinicia automáticamente para cargar el token
- [ ] `docker-compose.yml` NO tiene dependencias rotas por profiles
- [ ] Instalación completa exitosamente en servidor limpio Ubuntu/Debian
- [ ] `shellcheck install_aegis.sh` → 0 warnings
- [ ] `docker compose config` → 0 errors

---

## Testing Protocol

```bash
# 1. Clean slate
sudo bash uninstall_aegis.sh

# 2. Fresh install
sudo bash install_aegis.sh

# 3. Verify .env contents
cat /opt/aegis/Aegis-Installer/.env

# Expected output:
# AEGIS_ROOT_KEY=<64-char hex>
# ANK_TARGET=ank-server:50051
# AEGIS_FEATURES=
# AEGIS_WHISPER_MODEL=ggml-base.bin
# AEGIS_ALLOWED_ORIGINS=http://localhost:8000
# AEGIS_INSTALL_TOKEN=<token>

# 4. Verify containers
docker ps

# Expected: aegis-ank, aegis-shell (if web UI selected)

# 5. Check logs
docker compose -f /opt/aegis/Aegis-Installer/docker-compose.yml logs
```

---

## Commit Message

```
fix(installer): implement INST-116 + fix docker-compose deps [INST-HOTFIX-001]

- Generate complete .env (add WHISPER_MODEL, ALLOWED_ORIGINS)
- Capture ANK install token after container startup
- Auto-restart shell to inject token
- Remove broken depends_on (GPU profile conflict)
- Add AEGIS_INSTALL_TOKEN env var to shell service

BREAKING: Installation was completely broken. This hotfix unblocks launch.
Tested on Ubuntu 22.04 LTS and Debian 12.

Closes INST-HOTFIX-001
Implements INST-116 (was marked DONE but never merged)
```

---

## Dependencies

- None (hotfix urgente)

---

## Notes

Este hotfix debe mergearse a `main` INMEDIATAMENTE. El instalador actual no funciona en absoluto.

**SRE Impact:** CRITICAL — sistema no deployable
**User Impact:** CRITICAL — nadie puede instalar Aegis
**Urgency:** IMMEDIATE

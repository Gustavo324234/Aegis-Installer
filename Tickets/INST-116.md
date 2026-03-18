# [INST-116] Fix: Capture ANK install token and inject into BFF

**Epic:** 21 — Onboarding Fix
**Repo:** Aegis-Installer
**Files:** `install_aegis.sh`, `docker-compose.yml`
**Priority:** CRITICAL
**Status:** TODO

## Context

The ANK generates a one-time `install_token` at startup (logged to stdout).
The BFF needs this token to call `InitializeMasterAdmin`.
Currently the token is never captured or passed to the BFF.

## Required changes

### 1. `install_aegis.sh` — in `orchestrate()`, after `docker compose up -d`

Add after the containers start:
```bash
# Capture ANK install token and inject into .env for the BFF
log "Waiting for ANK to generate install token..."
local max_wait=30
local waited=0
local install_token=""

while [ "$waited" -lt "$max_wait" ]; do
    install_token=$("${compose_cmd[@]}" logs ank-server 2>/dev/null \
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

    # Restart shell container to pick up the new env var
    "${compose_cmd[@]}" "${profile_flag[@]}" restart aegis-shell >> "$LOG_FILE" 2>&1
    success "Shell restarted with install token."
else
    warn "Could not capture install token. Admin setup may require manual token entry."
fi
```

### 2. `docker-compose.yml` — service `aegis-shell`

Add to environment:
```yaml
environment:
  - ANK_TARGET=ank-server:50051
  - AEGIS_INSTALL_TOKEN=${AEGIS_INSTALL_TOKEN:-}
```

## Acceptance criteria

- [ ] After installation, `.env` contains `AEGIS_INSTALL_TOKEN=<token>`
- [ ] `aegis-shell` container has `AEGIS_INSTALL_TOKEN` env var set
- [ ] Admin setup from browser works without manual token entry
- [ ] `shellcheck install_aegis.sh` → 0 warnings

## Commit

```
fix(installer): capture ANK install token and inject into BFF [INST-116]
```

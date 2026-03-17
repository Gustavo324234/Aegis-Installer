# [INST-112] Smart Profiles + Systemd Hardening Fusion

**Epic:** 18 — MVP Public Launch
**Priority:** HIGH
**Repo:** Aegis-Installer
**File:** `install_aegis.sh`, `docker-compose.yml`

---

## 1. Context

Two workstreams need to be merged into a single coherent implementation:

- **INST-112**: Smart deployment profiles (Cloud/Local/Hybrid GPU + Web/Headless UI)
- **INST-STB-019**: Unprivileged `aegis` system user + systemd hardening

The current implementation of INST-STB-019 has three critical permission bugs that will cause the service to fail silently on any real deployment. This ticket fuses both workstreams and fixes all three bugs.

---

## 2. Bugs to fix (read the code before writing anything)

### Bug 1 — `aegis` user not in `docker` group
**Location:** `create_aegis_user()` function

Current code creates the user but never adds it to the `docker` group:
```bash
useradd --system --no-create-home --shell /sbin/nologin aegis
# Missing: usermod -aG docker aegis
```

The systemd service runs as `User=aegis`. Without docker group membership, every `docker compose` call fails with `Permission denied on /var/run/docker.sock`.

**Fix — add these lines inside `create_aegis_user()` after the useradd:**
```bash
# Add aegis to docker group so it can manage containers
if ! getent group docker &> /dev/null; then
    groupadd docker >> "$LOG_FILE" 2>&1 || true
fi
if ! id -nG aegis | grep -qw docker; then
    usermod -aG docker aegis >> "$LOG_FILE" 2>&1
    success "User 'aegis' added to docker group."
fi
```

### Bug 2 — `ProtectSystem=strict` blocks volume creation
**Location:** `install_systemd_service()` function

Current unit:
```ini
ProtectSystem=strict
ReadWritePaths=/opt/aegis /tmp
```

Docker needs to create `./users/` and `./models/` under `/opt/aegis/Aegis-Installer/` at runtime. `ProtectSystem=strict` makes the entire filesystem read-only except for `ReadWritePaths`. The current list covers the path, but Docker's socket and runtime directories are also needed.

**Fix — replace the hardening block in the unit file with:**
```ini
# Systemd hardening — defense in depth without breaking Docker volumes
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/aegis /tmp /var/run/docker.sock /var/lib/docker
PrivateTmp=true
```

Use `ProtectSystem=full` instead of `strict`. `strict` makes `/usr` and `/etc` read-only AND restricts `/` — too aggressive for a Docker orchestrator. `full` protects system dirs while allowing runtime writes where needed.

### Bug 3 — `sudo -u "$INVOKING_USER"` inside service context
**Location:** `orchestrate()` and `setup_workspace()` functions

When the script runs via systemd as `User=aegis`, `$INVOKING_USER` resolves to `aegis` (or is unset). The `sudo -u aegis` calls are redundant and will fail because `aegis` has no sudo rights.

**Fix — in `orchestrate()`, remove the sudo wrapper when already running as aegis:**
```bash
orchestrate() {
    log "Initializing Docker Orchestrator..."
    cd "$INSTALL_ROOT/Aegis-Installer" >> "$LOG_FILE" 2>&1

    local compose_cmd="docker compose"
    docker compose version &> /dev/null || compose_cmd="docker-compose"

    local profile_flag=""
    [ "$SELECTED_UI" == "web" ] && profile_flag="--profile frontend"

    # Pre-create volume directories with correct ownership before Docker tries
    mkdir -p "$INSTALL_ROOT/Aegis-Installer/users" \
             "$INSTALL_ROOT/Aegis-Installer/models" >> "$LOG_FILE" 2>&1
    chown aegis:aegis "$INSTALL_ROOT/Aegis-Installer/users" \
                      "$INSTALL_ROOT/Aegis-Installer/models" 2>/dev/null || true

    log "Executing deployment plan (profile: ${SELECTED_UI}, hw: ${HW_PROFILE})..."

    if [ "$HW_PROFILE" = "2" ]; then
        $compose_cmd $profile_flag up -d --build >> "$LOG_FILE" 2>&1 \
            || error "Orchestration failed. Check $LOG_FILE"
    else
        $compose_cmd $profile_flag pull >> "$LOG_FILE" 2>&1 \
            || warn "Image pull failed — continuing with cached images."
        $compose_cmd $profile_flag up -d >> "$LOG_FILE" 2>&1 \
            || error "Orchestration failed. Check $LOG_FILE"
    fi
}
```

The same applies to `setup_workspace()` — when running as `aegis` via systemd, replace `sudo -u "$INVOKING_USER" git ...` with a plain `git` call.

### Bug 4 — `default_root_key` fallback in docker-compose.yml
**Location:** `docker-compose.yml` line ~20

```yaml
AEGIS_ROOT_KEY=${AEGIS_ROOT_KEY:-default_root_key}
```

This must be removed. If `AEGIS_ROOT_KEY` is unset, the container must fail to start with a visible error — not silently use a known key. This is the `ANK-STB-020` requirement.

**Fix:**
```yaml
AEGIS_ROOT_KEY=${AEGIS_ROOT_KEY:?FATAL: AEGIS_ROOT_KEY is not set. Run the installer first.}
```

The `:?` operator causes bash/Docker to exit with the error message if the variable is unset or empty.

---

## 3. Smart Profiles integration

The profile selection logic in `configure_profiles()` is correct. The mapping needs to be consistent end-to-end. Verify these three things:

1. `SELECTED_FEATURES` is written to `.env` in `security_guard()` ✅ already done
2. `docker-compose.yml` reads `${AEGIS_FEATURES:-}` for the build arg ✅ already done  
3. The headless profile (`SELECTED_UI=headless`) skips `--profile frontend` in `orchestrate()` ✅ already done

No changes needed for profiles — they are correct. The only changes are the four bugs above.

---

## 4. Acceptance criteria

- [x] `create_aegis_user()` adds `aegis` to the `docker` group with `usermod -aG docker aegis`
- [x] `aegis.service` uses `ProtectSystem=full` not `strict`
- [x] `ReadWritePaths` includes `/var/run/docker.sock` and `/var/lib/docker`
- [x] `orchestrate()` pre-creates `users/` and `models/` directories before `docker compose up`
- [x] `orchestrate()` does not use `sudo -u` — runs directly as the current user
- [x] `docker-compose.yml` uses `:?` operator for `AEGIS_ROOT_KEY` — no default value
- [x] `shellcheck install_aegis.sh` — zero warnings
- [x] `docker compose config` — parses without errors
- [x] Manual test: `sudo bash install_aegis.sh --no-tui` completes without permission errors

---

## 5. Notes

Do not refactor anything outside the scope of these four bugs. The profile selection, TUI, banner, and logging are working correctly — leave them alone. Atomic change only.

After completing, update `CHANGELOG.md` and provide a Conventional Commit message:
```
fix(installer): docker group, ProtectSystem, volume ownership, root_key fallback [INST-112]
```

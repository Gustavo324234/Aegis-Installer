# [INST-113] Add progress feedback in TUI mode

**Epic:** 18 — MVP Public Launch
**Priority:** HIGH — blocks smoke test
**Repo:** Aegis-Installer
**File:** `install_aegis.sh`

---

## 1. Context

During the smoke test on Debian, the installer shows `[INFO] Synchronizing base dependencies...` and then goes completely silent for several minutes while `apt-get` runs. The user has no way to know if the system is working or frozen.

The same problem exists in the orchestration phase — `docker compose pull` can take several minutes on first run with no visual feedback.

---

## 2. Required changes

### Phase 2 — `install_dependencies()`

Add `dialog --infobox` calls before each slow operation in TUI mode:

```bash
install_dependencies() {
    [ "$USE_TUI" = true ] && clear
    log "Synchronizing base dependencies..."

    if [ "$USE_TUI" = true ]; then
        dialog --title "Phase 2: Dependencies" \
            --infobox "Updating package index...\nThis may take a moment." 5 55
    fi
    apt-get update -qq >> "$LOG_FILE" 2>&1

    local basic_deps=("git" "curl" "dialog" "openssl")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            if [ "$USE_TUI" = true ]; then
                dialog --title "Phase 2: Dependencies" \
                    --infobox "Installing $dep..." 5 40
            fi
            apt-get install -y "$dep" -qq >> "$LOG_FILE" 2>&1 \
                || error "Failed to install $dep"
        fi
    done

    if ! command -v docker &> /dev/null; then
        if [ "$USE_TUI" = true ]; then
            dialog --title "Phase 2: Dependencies" \
                --infobox "Installing Docker Engine...\nThis may take 2-3 minutes." 6 55
        fi
        log "Installing Docker Engine (Native Pipeline)..."
        curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1 \
            || error "Failed to install Docker"
        systemctl enable --now docker >> "$LOG_FILE" 2>&1
    fi

    if ! docker compose version &> /dev/null; then
        if [ "$USE_TUI" = true ]; then
            dialog --title "Phase 2: Dependencies" \
                --infobox "Installing Docker Compose plugin..." 5 50
        fi
        log "Installing Docker Compose Plugin..."
        apt-get install -y docker-compose-plugin -qq >> "$LOG_FILE" 2>&1 || {
            warn "Apt plugin failed, falling back to standalone..."
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
                -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
            chmod +x /usr/local/bin/docker-compose
        }
    fi

    if [ "$USE_TUI" = true ]; then
        dialog --title "Phase 2: Dependencies" \
            --infobox "All dependencies ready." 5 35
        sleep 1
    fi
}
```

### Phase 8 — `orchestrate()`

Replace the single infobox with step-by-step feedback:

```bash
# Before docker compose pull:
if [ "$USE_TUI" = true ]; then
    dialog --title "Phase 8: Deployment" \
        --infobox "Pulling Docker images from GHCR...\nThis may take several minutes on first run.\n\nLog: /tmp/aegis_install.log" 8 60
fi

# Before docker compose up:
if [ "$USE_TUI" = true ]; then
    dialog --title "Phase 8: Deployment" \
        --infobox "Starting Aegis OS containers..." 5 45
fi
```

---

## 3. Acceptance criteria

- [ ] During `apt-get update`, TUI shows "Updating package index..."
- [ ] During each package install, TUI shows "Installing <package>..."
- [ ] During Docker install, TUI shows "Installing Docker Engine... This may take 2-3 minutes."
- [ ] During `docker compose pull`, TUI shows "Pulling Docker images from GHCR..."
- [ ] During `docker compose up`, TUI shows "Starting Aegis OS containers..."
- [ ] `shellcheck install_aegis.sh` → 0 warnings
- [ ] `--no-tui` mode unaffected — no dialog calls run in headless mode

---

## 4. Conventional Commit

```
fix(installer): add progress feedback in TUI mode [INST-113]
```

# [INST-119] Fix Container Name Conflict in GPU Profile

**Epic:** 19 — Performance & Installer Hardening  
**Priority:** P0 — CRITICAL (Launch blocker)  
**Repo:** Aegis-Installer  
**Files:** `docker-compose.yml`, `install_aegis.sh`

---

## 1. Context

The installer fails with the following error when using GPU profile (`HW_PROFILE=3`):

```
services.ank-server-gpu: container name "aegis-ank" is already in use by service
[ERROR] Orchestration failed. Check /tmp/aegis_install.log
```

**Root cause:**  
Both `ank-server` and `ank-server-gpu` services in `docker-compose.yml` use the same `container_name: aegis-ank`. When the GPU profile is active, Docker Compose attempts to start both services simultaneously, causing a name collision.

**Current behavior:**
- `ank-server` (no profile) → always starts
- `ank-server-gpu` (profile: `gpu`) → conflicts with `ank-server`

**Impact:**
- Users with GPU hardware cannot install Aegis
- Users selecting HW_PROFILE=3 during installation get a critical error
- Blocks public launch (Epic 11)

---

## 2. Required Changes

### File 1: `docker-compose.yml`

Add `profiles: ["cpu"]` to the `ank-server` service to make it mutually exclusive with `ank-server-gpu`:

**Before:**
```yaml
  ank-server:
    image: ghcr.io/gustavo324234/aegis-ank:latest
    build:
      context: ../Aegis-ANK
      dockerfile: Dockerfile
      args:
        FEATURES: ${AEGIS_FEATURES:-}
    container_name: aegis-ank
    restart: unless-stopped
    user: "0"
    env_file:
      - .env
    environment:
      - RUST_LOG=info
    volumes:
      - ./users:/app/users
      - ./models:/app/models
      - ank-data:/app/data
    networks:
      - aegis_net
    expose:
      - "50051"
```

**After:**
```yaml
  ank-server:
    image: ghcr.io/gustavo324234/aegis-ank:latest
    build:
      context: ../Aegis-ANK
      dockerfile: Dockerfile
      args:
        FEATURES: ${AEGIS_FEATURES:-}
    container_name: aegis-ank
    profiles: ["cpu"]  # ← ADD THIS LINE
    restart: unless-stopped
    user: "0"
    env_file:
      - .env
    environment:
      - RUST_LOG=info
    volumes:
      - ./users:/app/users
      - ./models:/app/models
      - ank-data:/app/data
    networks:
      - aegis_net
    expose:
      - "50051"
```

---

### File 2: `install_aegis.sh`

Update the `orchestrate()` function to explicitly activate the CPU profile when not using GPU:

**Location:** Line ~360 (inside `orchestrate()` function)

**Before:**
```bash
# Build profile flags
local profile_flags=()
if [ "$SELECTED_UI" = "web" ]; then
    profile_flags+=("--profile" "frontend")
fi
if [ "$HW_PROFILE" = "3" ]; then
    profile_flags+=("--profile" "gpu")
fi
```

**After:**
```bash
# Build profile flags
local profile_flags=()
if [ "$SELECTED_UI" = "web" ]; then
    profile_flags+=("--profile" "frontend")
fi

# INST-119: Hardware profile selection - CPU vs GPU
if [ "$HW_PROFILE" = "3" ]; then
    profile_flags+=("--profile" "gpu")
else
    profile_flags+=("--profile" "cpu")
fi
```

**Optional:** Update version in banner (line 56):
```bash
echo -e "      Aegis OS Professional Bootstrapper - v1.4.4"
```

**Optional:** Update ticket list in header comment (line 14):
```bash
# Tickets: INST-109, INST-112, INST-113, INST-114, INST-119
```

---

## 3. Acceptance Criteria

- [ ] `docker-compose.yml` has `profiles: ["cpu"]` on line 9 (ank-server service)
- [ ] `install_aegis.sh` activates CPU profile when `HW_PROFILE != 3`
- [ ] Fresh installation with HW_PROFILE=1 (Cloud/Edge) succeeds
- [ ] Fresh installation with HW_PROFILE=2 (Local Monolith) succeeds
- [ ] Fresh installation with HW_PROFILE=3 (Hybrid GPU) succeeds
- [ ] No "container name already in use" errors in any profile
- [ ] Only one `aegis-ank` container runs at any time
- [ ] Both CPU and GPU profiles work independently without conflicts

---

## 4. Testing

### Test 1: CPU-only installation (HW_PROFILE=1)
```bash
# Clean state
sudo docker compose down --volumes
sudo docker ps -a | grep aegis | awk '{print $1}' | xargs -r sudo docker rm -f

# Execute installer
sudo ./install_aegis.sh --no-tui
# Select: HW_PROFILE=1 (Cloud/Edge)

# Verify
docker ps | grep aegis-ank
# Expected: 1 container named "aegis-ank" running with CPU profile
```

### Test 2: GPU installation (HW_PROFILE=3)
```bash
# Clean state
sudo docker compose down --volumes
sudo docker ps -a | grep aegis | awk '{print $1}' | xargs -r sudo docker rm -f

# Execute installer
sudo ./install_aegis.sh --no-tui
# Select: HW_PROFILE=3 (Hybrid GPU)

# Verify
docker ps | grep aegis-ank
# Expected: 1 container named "aegis-ank" running with GPU reservation
```

### Test 3: Manual profile activation
```bash
# Verify mutual exclusivity
sudo docker compose --profile cpu ps
# Expected: Only ank-server listed

sudo docker compose --profile gpu ps
# Expected: Only ank-server-gpu listed

sudo docker compose --profile cpu --profile gpu ps
# Expected: Both listed (but Docker will only start one due to same container_name)
```

### Test 4: Reinstallation scenario
```bash
# Simulate user with existing installation
sudo ./install_aegis.sh --no-tui  # First install
sudo ./install_aegis.sh --no-tui  # Reinstall without uninstall

# Expected: No conflicts, existing containers replaced gracefully
```

---

## 5. Dependencies

None — standalone fix.

---

## 6. Notes

- This fix makes `ank-server` and `ank-server-gpu` **mutually exclusive** by design
- Docker Compose will only activate one service based on the profile flags
- No changes to user experience (same TUI flow)
- Compatible with all existing `.env` files
- No impact on systemd service or other components

---

## 7. Workaround (For Immediate Unblock)

Users affected by this bug can apply the fix manually:

```bash
cd /opt/aegis/Aegis-Installer

# 1. Edit docker-compose.yml
sudo nano docker-compose.yml
# Add 'profiles: ["cpu"]' to ank-server service (line 9)

# 2. Clean up
sudo docker compose down --volumes
sudo docker ps -a | grep aegis | awk '{print $1}' | xargs -r sudo docker rm -f

# 3. Start with explicit profile
sudo docker compose --profile cpu --profile frontend up -d
```

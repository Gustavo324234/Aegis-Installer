# [INST-115] Fix: Show local IP instead of public IP in success screen

**Epic:** 11 — Open Source Launch
**Repo:** Aegis-Installer
**File:** `install_aegis.sh`
**Priority:** HIGH — affects UX on every installation
**Status:** TODO

---

## Context

The installer's final success screen currently shows the public IP fetched from `https://ifconfig.me`:

```
Nexus URL:    http://190.30.93.30:8000
```

This is wrong for two reasons:
1. Aegis is designed for private network use — the public IP is not the correct access URL
2. It exposes the user's public IP in the terminal output, which is a privacy concern
3. On servers without internet access, the curl call fails and falls back to `localhost`, which is also wrong

The correct URL is the **local network IP** of the server — the one other devices on the same LAN use to reach it.

---

## Required changes

In `install_aegis.sh`, replace the `print_success()` function's IP detection:

**Current (line 370):**
```bash
SERVER_IP=$(curl -s --connect-timeout 2 https://ifconfig.me 2>/dev/null || echo "localhost")
```

**Replace with:**
```bash
# Get the primary local network IP (the interface used for the default route)
SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}' | head -n1)

# Fallback chain: hostname -I → localhost
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
fi
```

This uses `ip route get` to find the IP of the interface that handles the default route — which is exactly the IP other devices on the LAN use to reach this server. No external HTTP call required.

---

## Acceptance criteria

- [ ] Success screen shows local LAN IP (e.g. `192.168.1.X`), not public IP
- [ ] No external HTTP calls in `print_success()` — works fully offline
- [ ] Fallback to `hostname -I` if `ip route get` fails
- [ ] Final fallback to `localhost` if both fail
- [ ] `shellcheck install_aegis.sh` → 0 warnings
- [ ] Tested on Debian: URL shown matches the IP used to access the UI from another device

---

## Dependencies

None.

---

## Commit message

```
fix(installer): show local LAN IP instead of public IP in success screen [INST-115]
```

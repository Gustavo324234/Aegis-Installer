# [INST-STB-019] Create unprivileged `aegis` user. Systemd hardening (`NoNewPrivileges`, `ProtectSystem`)

**Status**: DONE — 2026-03-17
**Epic**: 17 — Security Hardening Sprint
**Priority**: LOW
**Assignee**: DevOps Engineer

---

## Description

Create a dedicated unprivileged `aegis` system user and install a hardened `aegis.service` systemd unit so the orchestrator never runs as root at service-start time.

## Acceptance Criteria

- [x] `useradd --system --no-create-home --shell /sbin/nologin aegis` called idempotently (guarded by `id -u aegis` check)
- [x] `/etc/systemd/system/aegis.service` written with:
  - `User=aegis`
  - `NoNewPrivileges=true`
  - `ProtectSystem=strict`
  - `ProtectHome=true`
- [x] `systemctl daemon-reload` called after unit install; degrades gracefully if systemd is absent
- [x] `shellcheck install_aegis.sh` passes with zero warnings

## SRE Gate

```
shellcheck install_aegis.sh
```

## Changes

- `install_aegis.sh`: added phases 6 (`create_aegis_user`) and 7 (`install_systemd_service`); fixed `set -euo pipefail`; resolved SC2155/SC2034 warnings; initialized `SELECTED_FEATURES` and `SELECTED_UI` at global scope.
- `CHANGELOG.md`: entry added under `[Unreleased]`.
- `Tickets/INST-STB-019.md`: this file.

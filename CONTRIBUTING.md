# Contributing to Aegis OS

Thank you for your interest in contributing to Aegis OS. This document establishes the engineering standards that every contributor must follow across all Aegis repositories: **Aegis-ANK**, **Aegis-Shell**, and **Aegis-Installer**.

Aegis is SRE-grade software. We don't accept code that "works by coincidence." Every contribution must be maintainable, testable, and resilient at a production level.

---

## Table of contents

1. [Repository overview](#1-repository-overview)
2. [SRE Firewall — CI gate you must pass](#2-sre-firewall--ci-gate-you-must-pass)
3. [Zero-Panic policy](#3-zero-panic-policy)
4. [Zero-Trust policy](#4-zero-trust-policy)
5. [Architecture changes — RFC required](#5-architecture-changes--rfc-required)
6. [Ticket workflow](#6-ticket-workflow)
7. [Commit conventions](#7-commit-conventions)
8. [Test requirements](#8-test-requirements)
9. [Concurrency safety](#9-concurrency-safety)
10. [Setting up your environment](#10-setting-up-your-environment)

---

## 1. Repository overview

Aegis OS is a multi-repo cognitive operating system. Understanding the role of each repository before contributing is mandatory.

| Repo | Stack | Role |
|---|---|---|
| **Aegis-ANK** | Rust / Tokio / gRPC | Neural Kernel — cognitive scheduler, VCM, DAG compiler, Citadel auth, Wasm plugins |
| **Aegis-Shell** | TypeScript / React + Python / FastAPI | UI and BFF — thin client and gRPC proxy |
| **Aegis-Installer** | Bash | Zero-touch deploy orchestrator — Docker Compose, SRE pre-flight checks |
| **Aegis-Governance** | Markdown | Normative only — tickets, architecture docs, audit reports. Not executable. |

The **only public interface between ANK and Shell** is `kernel.proto` and `siren.proto`. Never bypass gRPC to communicate between these two components.

---

## 2. SRE Firewall — CI gate you must pass

Every pull request triggers an automated SRE gate. **Your PR cannot merge if any of these checks fail.**

### Aegis-ANK

```bash
# Clippy — zero warnings, zero unwrap, zero expect
cargo clippy --workspace --all-targets --all-features \
  -- -D warnings -D clippy::unwrap_used -D clippy::expect_used

# Full test suite
cargo test --workspace
```

### Aegis-Shell

```bash
# Python linting (BFF)
black --check bff/
flake8 bff/

# TypeScript build (UI)
cd ui && npm run build
```

### Aegis-Installer

```bash
# Shell linting
shellcheck install_aegis.sh
```

If you open a PR and the CI fails, fix it before requesting review. Do not ask maintainers to merge a failing PR.

---

## 3. Zero-Panic policy

This is the most important rule in the codebase. The Aegis Neural Kernel must **never crash** due to an unhandled error.

### In Aegis-ANK (Rust)

`.unwrap()`, `.expect()`, and `panic!()` are **strictly forbidden** in production code. Clippy is configured to reject them at the CI level — your code will not compile in CI if you use them.

**Wrong:**
```rust
let value = some_result.unwrap();
let conn = db.connect().expect("failed to connect");
```

**Correct:**
```rust
let value = some_result?;
let conn = db.connect().context("failed to connect to SQLCipher enclave")?;
```

Use `anyhow` for error propagation in binaries and `thiserror` for library error types. Every function that can fail must return `Result<T, E>`.

**Test functions are not exempt.** Tests must return `anyhow::Result<()>` and use `?` instead of `unwrap()`:

```rust
#[tokio::test]
async fn test_scheduler_enqueue() -> anyhow::Result<()> {
    let scheduler = CognitiveScheduler::new_in_memory().await?;
    let pid = scheduler.submit(mock_task()).await?;
    assert!(!pid.is_empty());
    Ok(())
}
```

### In Aegis-Shell (Python / BFF)

Use structured exception handling. Never let an exception propagate unhandled to the FastAPI router.

```python
# Wrong
result = ank_client.submit_task(request)

# Correct
try:
    result = await ank_client.submit_task(request)
except grpc.aio.AioRpcError as e:
    raise HTTPException(status_code=502, detail=f"Kernel unreachable: {e.code()}")
```

### In Aegis-Installer (Bash)

Every function must handle errors explicitly. Use `set -euo pipefail` at the top of all scripts. Never silently swallow command failures.

```bash
# Wrong
docker compose up -d

# Correct
if ! docker compose --profile frontend up -d --build; then
    error "Docker Compose failed. Check /tmp/aegis_install.log for details."
    exit 1
fi
```

---

## 4. Zero-Trust policy

Every call from Shell to ANK must carry Citadel credentials (`tenant_id` + `session_key`) in the gRPC metadata. There are no anonymous endpoints in the kernel — except `InitializeMasterAdmin`, which is restricted to localhost.

If you add a new gRPC method to `kernel.proto`, the `CitadelInterceptor` in `ank-server/src/auth/` applies automatically. Do not add authentication logic inside individual RPC handlers — that is the interceptor's job.

If you add a new HTTP endpoint to the BFF (`main.py`), it must extract credentials from the request and forward them as gRPC metadata via `AnkClient`. Never store `session_key` in a browser-accessible location (cookies, localStorage, query params).

---

## 5. Architecture changes — RFC required

Do not open a PR that introduces changes to any of the following without first opening a **GitHub Issue tagged `RFC`**:

- `kernel.proto` or `siren.proto` (contract changes affect both ANK and Shell)
- The Citadel authentication protocol
- The Virtual Context Manager (VCM) memory paging logic
- The DAG compiler or S-DAG topological validation
- `docker-compose.yml` service topology or network names
- Any new Cargo dependency that adds more than ~5MB to the binary

In the RFC issue, describe: what you want to change, why the current design is insufficient, and what the impact is on other repos. A maintainer must approve the RFC before implementation begins.

Small bugfixes, documentation improvements, and test additions do not require an RFC.

---

## 6. Ticket workflow

Aegis uses a two-level ticket system.

**Local tickets** (`TICKETS.md` in each repo) track work in progress within that repository. When you pick up a task, move its status to `[IN PROGRESS]`.

**Master index** (`TICKETS_MASTER.md` in Aegis-Governance) tracks cross-repo epics and milestones. You do not need to update this file for routine bugfixes. You must update it when:

- You close a ticket that is listed in an active Epic
- Your change affects the architecture, a public contract, or a security boundary
- You are opening a new Epic-level item

When you finish implementing a ticket, update `CHANGELOG.md` in the affected repo following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, then move the ticket to `[DONE]`.

---

## 7. Commit conventions

All commits and PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<scope>): <short description>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`

**Scopes by repo:**

| Repo | Valid scopes |
|---|---|
| Aegis-ANK | `kernel`, `scheduler`, `vcm`, `dag`, `citadel`, `plugins`, `siren`, `mcp`, `swarm`, `cli`, `proto` |
| Aegis-Shell | `bff`, `ui`, `auth`, `siren`, `telemetry`, `admin` |
| Aegis-Installer | `installer`, `compose`, `ci` |

**Examples:**

```
feat(installer): add --no-tui headless mode for CI deployments
fix(compose): correct ANK_TARGET env var name in docker-compose.yml
docs(installer): add WSL2 setup guide to README
chore(ci): update shellcheck version in pr_check workflow
```

Breaking changes must include `BREAKING CHANGE:` in the commit footer:

```
feat(compose)!: rename ank-server service to aegis-ank

BREAKING CHANGE: Any external scripts or clients referencing
the service name "ank-server" must be updated to "aegis-ank".
ANK_TARGET env var in Shell must also be updated.
```

---

## 8. Test requirements

### Aegis-ANK

Every module in `ank-core` must have a `#[cfg(test)]` block. Tests that require async must use `#[tokio::test]`. Tests must not depend on external state (network, filesystem, running kernel) — use in-memory constructors and mocks.

### Aegis-Shell

The BFF has a smoke test file at `bff/test_bff_smoke.py`. Add tests there for any new endpoint you introduce. Tests must be runnable with `pytest bff/` without a live kernel — mock the `AnkClient` where needed.

### Aegis-Installer

Shell scripts are validated with `shellcheck`. For behavioral testing of the install flow, document the manual verification steps in the PR description. At minimum, verify:

- `install_aegis.sh` passes `shellcheck` with no warnings
- `install_aegis.sh --no-tui` runs without errors in a clean Docker container
- `docker compose config` validates the compose file without errors

---

## 9. Concurrency safety

Aegis-ANK is an async Rust system running on Tokio. Concurrency bugs are the hardest to debug and the most dangerous in production.

**Rules:**

- Never call synchronous blocking I/O inside an async context. Use `tokio::task::spawn_blocking` for SQLite (`rusqlite`) and Git (`git2`) operations.
- When using `Arc<Mutex<T>>` or `Arc<RwLock<T>>`, add a comment explaining the locking order and why the design avoids deadlocks.
- Never hold a lock across an `.await` point.

```rust
// CONCURRENCY: This RwLock is only held for the duration of a HashMap
// lookup/insert. It is never held across .await points. Lock order:
// process_table > event_broker (never reversed) to prevent deadlock.
let mut table = self.process_table.write().await;
table.insert(pid.clone(), pcb);
```

When adding `unsafe` blocks, always include a `// SAFETY:` comment:

```rust
// SAFETY: LlamaNativeDriver wraps a C library that manages its own
// internal thread safety via mutex. The *mut pointer is never aliased
// across threads — each inference call acquires the internal lock.
unsafe impl Send for LlamaNativeDriver {}
```

---

## 10. Setting up your environment

### Prerequisites

- **Linux** (Debian/Ubuntu recommended) or **Windows with WSL2** — see the [WSL2 setup guide](README.md#2-quickstart--windows-wsl2)
- Docker Engine + Docker Compose V2
- For Aegis-ANK: Rust 1.80+, `protoc` (Protocol Buffers compiler)
- For Aegis-Shell: Python 3.11+, Node.js 20+
- For Aegis-Installer: Bash 5+, ShellCheck

### Quick local setup

```bash
# Clone inside Linux filesystem (not /mnt/c/ on WSL2)
git clone https://github.com/Gustavo324234/Aegis-Installer
cd Aegis-Installer

cp .env.example .env
# Edit .env: set AEGIS_ROOT_KEY

sudo ./install_aegis.sh

curl http://localhost:8000/health
curl http://localhost:8000/api/system/state
```

### Running linters locally before pushing

```bash
# ANK
cargo clippy --workspace --all-targets --all-features -- -D warnings -D clippy::unwrap_used -D clippy::expect_used
cargo test --workspace

# Shell
cd Aegis-Shell && black --check bff/ && flake8 bff/ && cd ui && npm run build

# Installer
shellcheck install_aegis.sh
```

---

## Code of conduct

Be direct, be technical, be respectful. Aegis is an engineering project. Reviews are about the code, not the person. Assume good intent.

Maintainers reserve the right to close PRs that do not follow this guide without extended explanation.

---

*This document applies to: Aegis-ANK, Aegis-Shell, Aegis-Installer.*
*Governance document: `Aegis-Governance/Tickets/EPIC_18_MVP_PUBLIC.md` — ticket GOV-106.*
*Last updated: 2026-03-16*

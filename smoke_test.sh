#!/usr/bin/env bash
# Aegis OS - Smoke Test Suite
# Validates the full stack after installation (Native or Docker)

set -euo pipefail

# --- Configuration ---
AEGIS_ROOT="${AEGIS_ROOT:-$(pwd)}"
DOTENV_PATH="$AEGIS_ROOT/.env"
PASSED=0
FAILED=0
TOTAL=7

# --- Helpers ---
log_pass() {
    echo -e "[\e[32mPASS\e[0m] $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "[\e[31mFAIL\e[0m] $1" >&2
    FAILED=$((FAILED + 1))
}

# Detect Mode
MODE="docker"
if [[ -f "$DOTENV_PATH" ]]; then
    if grep -q "AEGIS_INSTALL_MODE=native" "$DOTENV_PATH"; then
        MODE="native"
    fi
fi

echo "=== Aegis Smoke Test Suite ==="
echo "Mode: $MODE"
echo "Checking system readiness..."
echo ""

# 1. Logic provider check (Docker vs Supervisor)
if [[ "$MODE" == "docker" ]]; then
    if docker info >/dev/null 2>&1; then
        log_pass "Docker daemon is active"
    else
        log_fail "Docker daemon is not responding"
        exit 1
    fi
else
    if command -v aegis >/dev/null 2>&1; then
        log_pass "Aegis CLI is installed"
    else
        log_fail "Aegis CLI not found in PATH"
        exit 1
    fi
fi

# 2. Kernel Process/Container Check
if [[ "$MODE" == "docker" ]]; then
    if [[ -n $(docker ps --filter "name=aegis-ank" --filter "status=running" -q) ]]; then
        log_pass "Container 'aegis-ank' is running"
    else
        log_fail "Container 'aegis-ank' is NOT running"
    fi
else
    # En modo nativo buscamos el proceso o el estado via CLI
    if aegis status 2>/dev/null | grep -qi "Kernel.*UP"; then
        log_pass "ANK Keyboard is UP (Native)"
    else
        log_fail "ANK Keyboard is NOT reporting UP status"
    fi
fi

# 3. Shell Process/Container Check
if [[ "$MODE" == "docker" ]]; then
    if [[ -n $(docker ps --filter "name=aegis-shell" --filter "status=running" -q) ]]; then
        log_pass "Container 'aegis-shell' is running"
    else
        log_fail "Container 'aegis-shell' is NOT running"
    fi
else
    if aegis status 2>/dev/null | grep -qi "Shell.*UP"; then
        log_pass "Shell BFF is UP (Native)"
    else
        log_fail "Shell BFF is NOT reporting UP status"
    fi
fi

# 4. ANK health — port 50051 accessible
if nc -zv localhost 50051 >/dev/null 2>&1 || timeout 1 bash -c "</dev/tcp/localhost/50051" >/dev/null 2>&1; then
    log_pass "ANK gRPC port (50051) is accessible"
else
    log_fail "ANK gRPC port (50051) is NOT accessible"
fi

# 5. Shell BFF health — /api/status
if curl -sf --max-time 5 http://localhost:8000/api/status 2>/dev/null | grep -q '"state"'; then
    log_pass "Shell BFF /api/status is responding correctly"
else
    log_fail "Shell BFF /api/status failed or returned invalid response"
fi

# 6. Shell UI accessible
if curl -sfI --max-time 5 http://localhost:8000 >/dev/null 2>&1; then
    log_pass "Shell UI is accessible at http://localhost:8000"
else
    log_fail "Shell UI is NOT accessible"
fi

# 7. AEGIS_ROOT_KEY set in .env
if [[ -f "$DOTENV_PATH" ]]; then
    if grep -q "^AEGIS_ROOT_KEY=.\+" "$DOTENV_PATH"; then
        log_pass "AEGIS_ROOT_KEY is set in .env"
    else
        log_fail "AEGIS_ROOT_KEY is empty or missing in .env"
    fi
else
    log_fail ".env file not found at $DOTENV_PATH"
fi

# --- Summary ---
echo ""
echo "=== Aegis Smoke Test Results ==="
echo "Passed: $PASSED/$TOTAL"
echo "Failed: $FAILED/$TOTAL"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0

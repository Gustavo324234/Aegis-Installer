#!/usr/bin/env bash
# Aegis OS - Smoke Test Suite
# Validates the full stack after installation

set -euo pipefail

# --- Configuration ---
# Look for .env in the current directory or a specific path
DOTENV_PATH="${AEGIS_ROOT:-$(pwd)}/.env"
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

# --- Smoke Test Execution ---

echo "=== Aegis Smoke Test Suite ==="
echo "Checking system readiness..."
echo ""

# 1. Docker daemon active
if docker info >/dev/null 2>&1; then
    log_pass "Docker daemon is active"
else
    log_fail "Docker daemon is not responding"
    # Exit 1 immediately if Docker is not working
    echo ""
    echo "=== Aegis Smoke Test Results ==="
    echo "Passed: $PASSED/$TOTAL"
    echo "Failed: $FAILED/$TOTAL"
    exit 1
fi

# 2. Container ANK running
if [[ -n $(docker ps --filter "name=aegis-ank" --filter "status=running" -q) ]]; then
    log_pass "Container 'aegis-ank' is running"
else
    log_fail "Container 'aegis-ank' is NOT running"
fi

# 3. Container Shell running
if [[ -n $(docker ps --filter "name=aegis-shell" --filter "status=running" -q) ]]; then
    log_pass "Container 'aegis-shell' is running"
else
    log_fail "Container 'aegis-shell' is NOT running"
fi

# 4. ANK health — port 50051 accessible
if nc -zv localhost 50051 >/dev/null 2>&1; then
    log_pass "ANK gRPC port (50051) is accessible"
else
    log_fail "ANK gRPC port (50051) is NOT accessible"
fi

# 5. Shell BFF health — /api/status (Check if responding JSON with "state")
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
        log_pass "AEGIS_ROOT_KEY is set in $DOTENV_PATH"
    else
        log_fail "AEGIS_ROOT_KEY is empty or missing in $DOTENV_PATH"
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

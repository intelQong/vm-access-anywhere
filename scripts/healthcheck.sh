#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# healthcheck.sh
# Validates local Guacamole stack, container statuses, and XRDP accessibility.
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

# Detect docker command privileges
if ! docker ps >/dev/null 2>&1; then
    if sudo -n docker ps >/dev/null 2>&1; then
        COMPOSE="sudo docker compose"
    else
        echo "[-] Docker permission denied."
        exit 1
    fi
else
    COMPOSE="docker compose"
fi

echo "=== [1/4] Checking Docker Containers ==="
${COMPOSE} ps

echo ""
echo "=== [2/4] Testing Local Host XRDP Listener (Port 3389) ==="
if nc -z -w 3 127.0.0.1 3389 2>/dev/null; then
    echo "[OK] Host XRDP daemon is actively listening on 127.0.0.1:3389"
else
    echo "[FAIL] XRDP is not reachable on 127.0.0.1:3389"
    exit 1
fi

echo ""
echo "=== [3/4] Testing Local Guacamole HTTP Port (127.0.0.1:8080) ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/guacamole/ || echo "000")
if [[ "${HTTP_CODE}" =~ ^(200|302)$ ]]; then
    echo "[OK] Guacamole web client responded with HTTP ${HTTP_CODE} on localhost:8080"
else
    echo "[FAIL] Guacamole web client returned unexpected status code: ${HTTP_CODE}"
    echo "       Wait 15-30 seconds for Tomcat to initialize and retry."
    exit 1
fi

echo ""
echo "=== [4/4] Verifying Security Port Isolation ==="
# Verify port 8080 is NOT bound to 0.0.0.0 or public interface
PUBLIC_BINDING=$(sudo ss -tulpn | grep ':8080' | awk '{print $5}' || true)
echo "Port 8080 binding: ${PUBLIC_BINDING}"
if [[ "${PUBLIC_BINDING}" == *"127.0.0.1:8080"* && ! "${PUBLIC_BINDING}" == *"0.0.0.0:8080"* ]]; then
    echo "[OK] Port 8080 is strictly bound to 127.0.0.1 (safe from public internet access)."
else
    echo "[WARN] Check port binding to ensure it is not exposed on public interfaces."
fi

echo ""
echo "=== ALL HEALTH CHECKS PASSED ==="

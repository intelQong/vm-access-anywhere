#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# stop.sh
# Stops Guacamole container and optional services.
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "[*] Stopping Guacamole client container..."
if ! docker ps >/dev/null 2>&1; then
    COMPOSE="sudo docker compose"
else
    COMPOSE="docker compose"
fi

${COMPOSE} down
echo "[+] Guacamole client container stopped."

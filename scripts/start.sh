#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# start.sh
# Starts native guacd daemon and Guacamole client Docker container.
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "[*] Ensuring native guacd daemon is active..."
sudo systemctl enable --now guacd

# Ensure webapps/guacamole.war exists
if [[ ! -f "${ROOT_DIR}/webapps/guacamole.war" ]]; then
    echo "[*] webapps/guacamole.war not found. Downloading official Apache Guacamole 1.5.5..."
    mkdir -p "${ROOT_DIR}/webapps"
    curl -fsSL -o "${ROOT_DIR}/webapps/guacamole.war" https://archive.apache.org/dist/guacamole/1.5.5/binary/guacamole-1.5.5.war
    echo "[+] guacamole.war downloaded."
fi

# Ensure config/user-mapping.xml exists
if [[ ! -f "${ROOT_DIR}/config/user-mapping.xml" ]]; then
    if [[ -f "${ROOT_DIR}/config/user-mapping.xml.example" ]]; then
        echo "[*] Creating config/user-mapping.xml from example template..."
        cp "${ROOT_DIR}/config/user-mapping.xml.example" "${ROOT_DIR}/config/user-mapping.xml"
    fi
fi

echo "[*] Starting Guacamole client container..."
if ! docker ps >/dev/null 2>&1; then
    COMPOSE="sudo docker compose"
else
    COMPOSE="docker compose"
fi

${COMPOSE} up -d

echo ""
echo "[*] Running healthcheck..."
"${SCRIPT_DIR}/healthcheck.sh"

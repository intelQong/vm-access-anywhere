#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# setup-tunnel.sh
# Connects this VM's Guacamole instance to Cloudflare Zero Trust.
# Supports:
#   1. Zero Trust Dashboard Token (Recommended, 1-step)
#   2. Cloudflare CLI Login (cloudflared tunnel login)
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

SERVICE_NAME="cloudflared-vm-access"
FULL_HOSTNAME="desktop.intelqong.link"

echo "=================================================================="
echo " Cloudflare Zero Trust Tunnel Setup"
echo " Hostname : https://${FULL_HOSTNAME}/guacamole/"
echo " Target   : http://127.0.0.1:8080"
echo "=================================================================="

# Check if token provided as argument
TOKEN="${1:-}"

if [[ -z "${TOKEN}" ]]; then
    echo ""
    echo "To connect this VM to Cloudflare Zero Trust:"
    echo "1. Go to https://one.dash.cloudflare.com"
    echo "2. Navigate to Networks -> Tunnels -> 'Create a tunnel'"
    echo "3. Choose Cloudflared, name it 'vm-access-anywhere', and save"
    echo "4. Under 'Install and run a connector', copy the Tunnel Token from the box"
    echo "   (the long string starting with eyJh...)"
    echo "5. Under 'Public Hostname':"
    echo "   - Subdomain: desktop"
    echo "   - Domain: intelqong.link (or your domain)"
    echo "   - Service Type: HTTP"
    echo "   - URL: 127.0.0.1:8080"
    echo ""
    read -rp "Paste your Cloudflare Tunnel Token (or type 'login' for CLI login): " INPUT_VAL

    if [[ "${INPUT_VAL}" == "login" ]]; then
        echo "[*] Launching cloudflared tunnel login..."
        cloudflared tunnel login
        read -rp "Enter tunnel name to create (e.g. vm-access-anywhere): " T_NAME
        cloudflared tunnel create "${T_NAME}"
        cloudflared tunnel route dns "${T_NAME}" "${FULL_HOSTNAME}"
        echo "[+] Route configured. Run with: cloudflared tunnel run ${T_NAME}"
        exit 0
    else
        TOKEN="${INPUT_VAL}"
    fi
fi

if [[ -z "${TOKEN}" ]]; then
    echo "[-] Error: No token provided."
    exit 1
fi

echo "[*] Installing and configuring systemd service for Cloudflare Tunnel..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

sudo bash -c "cat <<EOF > ${SERVICE_FILE}
[Unit]
Description=Cloudflare Tunnel for VM Access Anywhere (${FULL_HOSTNAME})
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/cloudflared tunnel run --token ${TOKEN}
Restart=always
RestartSec=5s
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF"

echo "[*] Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}.service"
sudo systemctl restart "${SERVICE_NAME}.service"

sleep 3
sudo systemctl status "${SERVICE_NAME}.service" --no-pager

echo ""
echo "=================================================================="
echo " [SUCCESS] Cloudflare Tunnel service is active!"
echo " Service : ${SERVICE_NAME}.service"
echo " Endpoint: https://${FULL_HOSTNAME}/guacamole/"
echo "=================================================================="

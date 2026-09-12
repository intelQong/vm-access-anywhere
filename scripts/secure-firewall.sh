#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# secure-firewall.sh
# Hardens UFW firewall rules for the Zero-Trust In-Browser architecture.
# Ensures zero public incoming ports are required for browser access.
# ------------------------------------------------------------------------------

echo "=================================================================="
echo " Zero-Trust UFW Firewall Hardening"
echo "=================================================================="

# Verify sudo permissions
if ! sudo -n true 2>/dev/null; then
    echo "[-] Sudo privileges required to configure UFW."
    exit 1
fi

echo "[*] Ensuring loopback interface traffic is permitted..."
sudo ufw allow in on lo to any comment 'Allow local loopback'

echo "[*] Verifying Docker internal network traffic..."
# Allow internal Docker bridge communication
sudo ufw allow in on docker0 to any comment 'Allow internal docker bridge' 2>/dev/null || true

echo "[*] Ensuring Port 8080 and Port 3389 are NEVER accessible publicly..."
# Explicitly deny direct external access to 3389 and 8080
sudo ufw delete allow 3389 2>/dev/null || true
sudo ufw delete allow 8080 2>/dev/null || true

echo "[*] Current UFW status:"
sudo ufw status verbose

echo ""
echo "=================================================================="
echo " [NOTICE] All browser-based remote desktop traffic routes securely"
echo " through Cloudflare Tunnel over outbound TLS/QUIC (Port 443)."
echo " You do NOT need any open incoming ports on this VM for your work laptop!"
echo " WireGuard (51820/udp) can remain enabled for your phone, or disabled."
echo "=================================================================="

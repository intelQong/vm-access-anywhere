# 🌐 VM Access Anywhere

> **Enterprise-Grade, Zero-Footprint Remote Desktop Access for Linux VMs via Apache Guacamole & Cloudflare Zero Trust.**  
> Access your graphical Linux workstation from any corporate or personal laptop with **zero software installed**, **zero persistent configuration files**, and **zero open inbound firewall ports**.

---

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-20%2B-blue.svg)](https://www.docker.com/)
[![Architecture](https://img.shields.io/badge/Arch-ARM64%20%7C%20AMD64-success.svg)](#)
[![Cloudflare Zero Trust](https://img.shields.io/badge/Cloudflare-Zero%20Trust-orange.svg)](https://one.dash.cloudflare.com)
[![Protocol](https://img.shields.io/badge/Security-2FA%20%2F%20Passkey-green.svg)](#)

---

## 📌 The Problem: The Corporate Laptop Dilemma

Many developers and engineers maintain powerful remote Linux VMs running desktop environments (KDE, XFCE, GNOME) over XRDP. To secure these instances, standard practice relies on a strict **WireGuard VPN** tunnel (`wg0.conf`), dropping all inbound traffic from the public internet.

However, when connecting frequently from a **work laptop**, serious security and operational risks emerge:

1. **Config & Key Exposure**: The client configuration file (`laptop.conf`) containing your private key, internal subnet routes (`10.100.0.0/24`), and the server's public IP endpoint sits on the work laptop's drive.
2. **Accidental Retention**: If you forget to delete the configuration, it remains permanently accessible. It can be automatically ingested by corporate backup agents (OneDrive, Google Drive, Time Machine), flagged by corporate Endpoint Detection & Response (EDR) software (CrowdStrike, Defender for Endpoint), or discovered during IT audits.
3. **Privilege & Policy Restrictions**: Corporate laptops rarely allow employees to install low-level network drivers or TUN/TAP adapters required by VPN clients.

---

## 🛡️ The Solution: Zero-Trust In-Browser Access

**VM Access Anywhere** completely eliminates the need to install VPN clients or store secret keys on your work laptop.

```mermaid
flowchart TD
    subgraph Client ["💻 WORK LAPTOP (Zero Footprint)"]
        direction TB
        Browser["Standard Web Browser\nChrome / Edge / Firefox / Safari"]
        BrowserNotes["• Zero bytes saved to disk\n• No VPN clients or TAP drivers\n• Standard Outbound HTTPS (Port 443) only\n• Incognito / Private window friendly"]
        Browser --- BrowserNotes
    end

    subgraph Edge ["☁️ CLOUDFLARE GLOBAL EDGE NETWORK"]
        direction TB
        DNS["1. DNS Resolution\ndesktop.intelqong.com"]
        AccessGate["2. Cloudflare Zero Trust (Access Gate)\n• Email One-Time PIN (OTP) or Google SSO\n• FIDO2 Passkey / Hardware Security Key\n• Edge Authentication & Session Timeout"]
        EdgeProxy["3. Encrypted Anycast Proxy"]
        DNS --> AccessGate --> EdgeProxy
    end

    subgraph TargetVM ["🖥️ TARGET LINUX VM (Zero Inbound Ports)"]
        direction TB
        subgraph Ingress ["Outbound Secure Tunnel"]
            Cloudflared["cloudflared Service (Systemd)\nOutbound-only QUIC / TLS Tunnel"]
        end

        subgraph WebStack ["Guacamole Web Stack"]
            GuacClient["Guacamole Web Client (Docker)\nNative ARM64 / AMD64 Tomcat 9\nStrictly bound to 127.0.0.1:8080"]
            GuacdDaemon["guacd Translation Daemon (Systemd)\nNative C FreeRDP Accelerator\n12MB RAM Footprint"]
        end

        subgraph DesktopSession ["Desktop Environment"]
            XRDP["Host XRDP Server\nListening on 127.0.0.1:3389"]
            KDE["KDE Plasma Linux Workstation\nDynamic Scaling | Audio | Clipboard"]
        end

        Cloudflared -->|"Loopback HTTP"| GuacClient
        GuacClient -->|"Native IPC (4822)"| GuacdDaemon
        GuacdDaemon -->|"Localhost RDP"| XRDP
        XRDP --> KDE
    end

    Browser -->|"HTTPS / WSS (Port 443)"| DNS
    EdgeProxy -->|"Outbound QUIC / TLS Tunnel (No open ports)"| Cloudflared
```

### 💡 How It Works (At a Glance)
1. **Zero-Trace Client**: Connect from any browser (even Incognito). Exactly **0 bytes** of config files, VPN software, or private keys are saved to the work laptop.
2. **Edge-Level 2FA**: Cloudflare Access intercepts the connection at Cloudflare's edge, requiring multi-factor authentication (Email OTP or FIDO2 Passkey) before any packet can reach your server.
3. **Outbound-Only Pipe**: A persistent `cloudflared` tunnel initiates an outbound encrypted QUIC stream to Cloudflare, meaning **zero public inbound ports** are ever opened on your VM firewall.
4. **Local Hardware Bridge**: Apache Guacamole and native `guacd` convert your local XRDP session (`127.0.0.1:3389`) into an interactive HTML5/WebSocket stream with 60 FPS responsiveness, audio, and clipboard sync.

---

## ✨ Key Advantages

| Metric | Traditional WireGuard | VM Access Anywhere |
| :--- | :--- | :--- |
| **Work Laptop Footprint** | Static `.conf` & private key stored on disk | **0 bytes written to disk** (pure browser session) |
| **Admin Rights Needed** | Yes (to create VPN network adapters) | **None** (runs in standard unprivileged browser) |
| **Corporate Visibility** | Non-standard UDP tunnel & VPN software | Indistinguishable from standard HTTPS web browsing |
| **Public Ports Open** | Requires UDP port `51820` open to internet | **Zero public ports** (100% outbound Cloudflare tunnel) |
| **Authentication** | Static asymmetric key pair | **MFA / 2FA** (Email OTP, Hardware Passkey, Google SSO) |
| **Session Control** | Unlimited until manually disconnected | Automatic timeout policies (1h, 4h, or on tab close) |
| **Cost** | Free (self-hosted) | **100% Free** (Open Source + Cloudflare Free Tier up to 50 users) |

---

## 🚀 Quickstart Guide

### Prerequisites
- A Linux VM (Ubuntu 22.04 / 24.04 recommended on ARM64 or x86_64).
- Docker and Docker Compose installed.
- A running XRDP desktop session on `127.0.0.1:3389`.
- A domain managed on Cloudflare (free tier).

### 1. Clone & Set Permissions
```bash
cd ~
git clone git@github.com:intelQong/vm-access-anywhere.git
cd vm-access-anywhere
chmod +x scripts/*.sh
```

### 2. Configure Credentials
Copy the example environment template and customize your connection credentials:
```bash
cp .env.example .env
```
Edit `config/user-mapping.xml` to set your desired web login username and password:
```xml
<user-mapping>
    <authorize username="your_username" password="your_secure_password">
        <connection name="Remote Desktop">
            <protocol>rdp</protocol>
            <param name="hostname">host.docker.internal</param>
            <param name="port">3389</param>
            <param name="ignore-cert">true</param>
            <param name="resize-method">display-update</param>
            <param name="enable-audio">true</param>
        </connection>
    </authorize>
</user-mapping>
```

### 3. Start the Stack
Run the automated startup script:
```bash
./scripts/start.sh
```
This script will:
- Enable and start the native, hardware-accelerated `guacd` daemon on the host.
- Download the official Apache Guacamole WAR if not already present.
- Launch the containerized client bound strictly to `127.0.0.1:8080`.
- Execute a comprehensive health check.

### 4. Connect Cloudflare Zero Trust Tunnel
Run the tunnel setup wizard:
```bash
./scripts/setup-tunnel.sh
```
1. Visit the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2. Navigate to **Networks** ➔ **Tunnels** ➔ **Create a tunnel**.
3. Choose `cloudflared`, give it a name (e.g., `vm-access-anywhere`), and copy the connector token.
4. Paste the token into the script prompt.
5. In the Cloudflare dashboard under **Public Hostnames**:
   - **Subdomain**: `desktop`
   - **Domain**: `yourdomain.com`
   - **Type**: `HTTP`
   - **URL**: `127.0.0.1:8080`

### 5. Enforce Cloudflare Access 2FA / MFA
To lock down your endpoint with multi-factor authentication:
1. In the Cloudflare Zero Trust dashboard, go to **Access** ➔ **Applications** ➔ **Add an application**.
2. Select **Self-hosted**.
3. Application name: `VM Remote Desktop`.
4. Subdomain: `desktop.yourdomain.com`.
5. Under **Policies**, add an **Allow** rule:
   - **Action**: Allow
   - **Rule Type**: Include ➔ *Emails* (enter your personal email address).
6. Under **Identity Providers**, enable **One-Time PIN (OTP)**, **Google Workspace**, or **Passkey / FIDO2**.
7. Save the application.

---

## 🔒 Firewall Hardening (Zero Inbound Ports)

Because Cloudflare Tunnel initiates outbound TLS/QUIC connections to Cloudflare edge nodes, your VM **does not require any inbound ports**.

Run the hardening script:
```bash
sudo ./scripts/secure-firewall.sh
```

To achieve total stealth (invisible to Shodan and automated port scanners):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on lo
sudo ufw reload
```
> **Note**: If you still use WireGuard for your personal phone, keep UDP port `51820` open. If you connect solely via the browser, you can safely close WireGuard as well.

---

## 💻 Daily Usage from Work Laptop

1. Open Chrome or Edge (regular or Incognito window).
2. Navigate to `https://desktop.yourdomain.com/guacamole/`.
3. Cloudflare Access intercepts: enter your email and submit the 6-digit One-Time PIN (or touch your hardware Passkey).
4. Enter your Guacamole credentials.
5. **Your Linux desktop appears instantly** with:
   - Full 60 FPS graphical rendering.
   - Dynamic resolution scaling (resizing the browser window resizes the desktop session).
   - Bidirectional copy/paste clipboard synchronization.
   - Low-latency audio streaming.
6. When done, simply **close the browser tab**. Zero trace remains on the work laptop.

---

## 🛠️ Operational Commands

| Command | Action |
| :--- | :--- |
| `./scripts/start.sh` | Starts `guacd` daemon, launches Guacamole container, runs healthcheck |
| `./scripts/stop.sh` | Stops the Guacamole container |
| `./scripts/healthcheck.sh` | Validates container status, port isolation, and XRDP responsiveness |
| `sudo systemctl status guacd` | Check native translation proxy daemon status |
| `sudo systemctl status cloudflared-vm-access` | Check background Cloudflare Tunnel daemon status |
| `sudo docker logs -f guacamole-client` | Tail live Guacamole web client application logs |

---

## 📂 Repository Structure

```
vm-access-anywhere/
├── config/
│   ├── guacamole.properties       # Core Guacamole daemon linkage
│   └── user-mapping.xml           # User credentials and RDP parameters
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-09-12-vm-access-anywhere-design.md
│       └── plans/
│           └── 2026-09-12-vm-access-anywhere-plan.md
├── scripts/
│   ├── start.sh                   # One-touch startup with auto-downloads
│   ├── stop.sh                    # Clean container shutdown
│   ├── healthcheck.sh             # 4-stage system and security verifier
│   ├── setup-tunnel.sh            # Cloudflare Tunnel automated provisioning
│   └── secure-firewall.sh         # Zero-trust UFW firewall hardening
├── systemd/
│   └── cloudflared-vm-access.service  # Systemd service unit template
├── .env.example                   # Environment variable template
├── .gitignore                     # Leak-prevention filter
├── docker-compose.yml             # Native ARM64/AMD64 Tomcat 9 service definition
├── PROGRESS.md                    # Project tracking checklist
└── README.md                      # Executive documentation
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

# System Design: VM Access Anywhere (Zero-Trust In-Browser Remote Desktop)

**Document ID:** `SPEC-2026-09-12-VM-ACCESS-ANYWHERE`  
**Status:** Approved  
**Author:** Antigravity / intelQong  
**Domain Target:** `desktop.intelqong.link` (Zone: `intelqong.link`)

---

## 1. Executive Summary & Problem Statement

### 1.1 The Core Dilemma
The user manages a remote Linux VM running graphical applications (KDE Plasma over XRDP). The existing security model relies entirely on a strict WireGuard VPN (`wg0.conf`), where all incoming ports (including 3389 and 22) are blocked by UFW from the public internet and only accessible through the WireGuard interface.

When connecting from a corporate/work laptop:
1. **Config & Key Exposure**: The WireGuard client configuration file (`laptop.conf`) containing private keys, internal subnet details (`10.100.0.0/24`), and the VM's public IP endpoint (`<VM_PUBLIC_IP>:51820`) is stored on the work laptop.
2. **Forgetfulness & Accidental Retention**: If the user forgets to purge `laptop.conf` or the WireGuard tunnel from the work machine, it may be indexed by corporate Endpoint Detection and Response (EDR) software, backed up by corporate cloud sync (OneDrive, Google Drive), or exposed during IT audits/laptop returns.
3. **Privilege & Policy Conflicts**: Installing or running kernel/TUN-based VPN clients like WireGuard frequently violates corporate security compliance and often requires local administrative privileges that may be restricted.

### 1.2 The Objective
Establish a **Zero-Footprint, Zero-Trust In-Browser Remote Desktop Solution** that:
- Leaves **zero persistent files, credentials, or keys** on the work laptop.
- Requires **no software installation** or administrative privileges on the work machine (standard Chrome / Edge browser in regular or Incognito mode).
- Keeps the VM completely invisible to the public internet by requiring **zero incoming public firewall ports** (using an outbound-only Cloudflare Tunnel).
- Protects the session with **Multi-Factor Authentication (MFA / 2FA)** at Cloudflare's global edge before any connection can reach the VM.
- Connects directly to the existing high-performance XRDP / KDE desktop on `127.0.0.1:3389`.
- Is **100% free** to operate using open-source Apache Guacamole and Cloudflare Zero Trust Free Tier (up to 50 users).

---

## 2. Architecture & Network Topology

```
+-----------------------------------------------------------------------------------+
|                                  WORK LAPTOP                                      |
|                                                                                   |
|   +---------------------------------------------------------------------------+   |
|   |  Web Browser (Chrome / Edge / Firefox - Incognito Supported)              |   |
|   |  - Zero files written to disk                                             |   |
|   |  - Zero network drivers / TAP devices installed                           |   |
|   |  - Standard Outbound HTTPS (Port 443) only                                |   |
|   +---------------------------------------------------------------------------+   |
+-----------------------------------------|-----------------------------------------+
                                          |
                                          | HTTPS / WSS (Port 443)
                                          v
+-----------------------------------------------------------------------------------+
|                        CLOUDFLARE GLOBAL EDGE NETWORK                             |
|                                                                                   |
|   +---------------------------------------------------------------------------+   |
|   |  1. DNS Resolution: desktop.intelqong.link                                |   |
|   |  2. Cloudflare Zero Trust (Access Gate)                                   |   |
|   |     - Email One-Time PIN (OTP) / Google SSO / Passkey (FIDO2/WebAuthn)    |   |
|   |     - Session Timeout Enforcement (e.g., 2h / 4h / per-session)           |   |
|   |     - Identity verification before reaching host                          |   |
|   +---------------------------------------------------------------------------+   |
+-----------------------------------------|-----------------------------------------+
                                          |
                                          | Encrypted Outbound QUIC/HTTP2 Tunnel
                                          | (No Inbound Firewall Ports Needed!)
                                          v
+-----------------------------------------------------------------------------------+
|                                 TARGET LINUX VM                                   |
|                                                                                   |
|   [UFW Firewall: Default Deny Inbound | Zero Public Ports Open for Access]        |
|                                                                                   |
|   +---------------------------------------------------------------------------+   |
|   |  cloudflared daemon (systemd service)                                     |   |
|   |  - Maintains outbound tunnel to Cloudflare Edge                           |   |
|   |  - Ingress: desktop.intelqong.link -> http://127.0.0.1:8080/guacamole    |   |
|   +-------------------------------------|-------------------------------------+   |
|                                         | Loopback HTTP (127.0.0.1:8080)          |
|                                         v                                         |
|   +---------------------------------------------------------------------------+   |
|   |  Docker Stack: Apache Guacamole                                           |   |
|   |                                                                           |   |
|   |   +-------------------------+         +-------------------------------+   |   |
|   |   | guacamole-client        | <-----> | guacd (RDP Translation Proxy) |   |   |
|   |   | (Java Web Application)  |         | (C Daemon)                    |   |   |
|   |   +------------|------------+         +---------------|---------------+   |   |
|   |                |                                      |                   |   |
|   |                v                                      | Local RDP         |   |
|   |   +-------------------------+                         | (Port 3389)       |   |
|   |   | postgres-guacamole      |                         |                   |   |
|   |   | (User Auth, TOTP, Logs) |                         |                   |   |
|   |   +-------------------------+                         v                   |   |
|   +-------------------------------------------------------|-------------------+   |
|                                                           v                       |
|   +---------------------------------------------------------------------------+   |
|   |  Host XRDP Server (127.0.0.1:3389)                                        |   |
|   |  - Sesman -> Xorg -> KDE Plasma Desktop Session (/home/ubuntu)            |   |
|   +---------------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------------+
```

---

## 3. Core Component Specifications

### 3.1 Apache Guacamole Stack
Apache Guacamole is a clientless remote desktop gateway supporting standard protocols like RDP, VNC, and SSH. It renders the remote desktop into HTML5 Canvas and transmits input/display changes over optimized WebSockets.

* **Containers deployed**:
  1. `guacd`: The Guacamole translation proxy daemon (lightweight native C daemon).
  2. `guacamole`: The HTML5 client web app (Tomcat/Java based). Configured to bind exclusively to `127.0.0.1:8080`.
  3. `guacamole-db`: PostgreSQL database storing hashed credentials, connection profiles, session histories, and optional secondary TOTP secrets.
* **RDP Bridge parameters**:
  - Host: `host.docker.internal` or host gateway (`172.17.0.1`)
  - Port: `3389`
  - Security Mode: `any` (negotiated TLS / RDP encryption)
  - Ignore Server Certificate: `true` (handles self-signed XRDP certificates)
  - Audio Support: Enabled
  - Clipboard Integration: Bidirectional clipboard sync enabled via HTML5 clipboard API

### 3.2 Cloudflare Tunnel (`cloudflared`)
* Outbound daemon connecting directly to Cloudflare's closest Anycast edge nodes.
* Eliminates dynamic DNS, port forwarding, public IP exposure, and port opening.
* Ingress configuration maps `desktop.intelqong.link` to `http://127.0.0.1:8080/guacamole`.
* Integrated as a managed `systemd` service for automatic boot recovery.

### 3.3 Cloudflare Access (Identity & 2FA Gate)
* Enforces Zero-Trust identity verification at Cloudflare's edge.
* **Policy**:
  - Action: `Allow`
  - Rule: `Include Emails` matching the authorized administrator email.
  - Authentication methods: One-Time PIN (OTP) sent to email, Google Workspace SSO, or Passkey/FIDO2.
  - Session Duration: 24 hours max, or per-session.

### 3.4 UFW Firewall Hardening
* The public WireGuard port `51820/udp` can either be retained solely for mobile (`iphone.conf`) or closed completely when not needed.
* Port `3389/tcp` remains bound to localhost/internal interfaces only; external access from the public internet is permanently dropped.

---

## 4. Security & Threat Model Analysis

| Threat Vector | Traditional WireGuard Setup | In-Browser Zero-Trust Setup |
| :--- | :--- | :--- |
| **Forgotten Config on Work Laptop** | High risk (`laptop.conf` persists with private key & server IP). | **Zero risk** (no files, keys, or configs ever touch work disk). |
| **Corporate EDR / DLP Inspection** | WireGuard driver, config files, and VPN traffic detected. | Looks like standard HTTPS traffic in web browser. |
| **Port Scanning / Reconnaissance** | Port `51820/udp` responds to probes. | **Zero public listening ports**. VM appears dark to Shodan/nmap. |
| **Stolen Credentials / Session Hijacking** | Leaked config allows immediate network access. | Must pass Cloudflare Edge 2FA (Email OTP / Passkey) + Guacamole auth. |
| **Brute Force on RDP (Port 3389)** | Mitigated by WireGuard, but open to compromised VPN peers. | 3389 is never exposed; only `guacd` accesses it locally. |

---

## 5. Directory & File Organization

The project will reside in `/home/ubuntu/vm-access-anywhere`:

```
/home/ubuntu/vm-access-anywhere/
├── docker-compose.yml              # Guacamole, guacd, and PostgreSQL definitions
├── .env.example                    # Template for database credentials and domain settings
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-09-12-vm-access-anywhere-design.md
│       └── plans/
│           └── 2026-09-12-vm-access-anywhere-plan.md
├── scripts/
│   ├── init-database.sh            # Generates Guacamole schema into PostgreSQL
│   ├── setup-tunnel.sh             # Configures Cloudflare Tunnel via credentials
│   ├── secure-firewall.sh          # Applies zero-trust UFW firewall rules
│   └── healthcheck.sh              # Validates guacd, web app, and tunnel reachability
├── PROGRESS.md                     # Implementation milestone checklist
└── README.md                       # Comprehensive, professional documentation
```

---

## 6. Verification Criteria
1. Guacamole stack starts cleanly via Docker Compose and binds only to `127.0.0.1:8080`.
2. Cloudflare Tunnel establishes an active connection to `desktop.intelqong.link`.
3. Cloudflare Access intercepts browser requests and demands 2FA/OTP verification.
4. After authentication, the KDE Plasma desktop renders smoothly inside the browser with responsive mouse, keyboard, and clipboard.
5. Work laptop requires no downloads or configuration—only a browser URL.

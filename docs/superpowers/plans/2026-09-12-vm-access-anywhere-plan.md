# VM Access Anywhere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish an enterprise-grade, zero-footprint, in-browser remote desktop access system for the Linux VM over Cloudflare Zero Trust and Apache Guacamole, eliminating the need to store WireGuard configuration files on work laptops.

**Architecture:** Apache Guacamole and `guacd` run in Docker on the VM, translating the local XRDP session (`127.0.0.1:3389`) into an HTML5/WebSocket web application bound locally to `127.0.0.1:8080`. An outbound-only Cloudflare Tunnel connects this web app to `desktop.intelqong.link` protected by Cloudflare Access MFA/OTP at the edge, requiring zero public incoming firewall ports.

**Tech Stack:** Docker, Docker Compose, Apache Guacamole, guacd, PostgreSQL, Cloudflare Tunnel (`cloudflared`), Cloudflare Access, UFW, XRDP, Bash, Git.

**Spec:** `docs/superpowers/specs/2026-09-12-vm-access-anywhere-design.md`

## Global Constraints

- Never expose port 8080 or port 3389 directly to the public internet; all web traffic must route via loopback (`127.0.0.1`) through Cloudflare Tunnel.
- Ensure all passwords and database secrets are parameterized via environment variables (`.env`).
- Never check plain-text `.env` credentials into git; provide a clear `.env.example`.
- Git commits must follow conventional commit standards (`feat:`, `chore:`, `docs:`, `fix:`).
- All scripts must have executable permissions (`chmod +x`) and proper error handling (`set -euo pipefail`).

---

### Task 1: Project Scaffolding & Docker Compose Stack

**Files:**
- Create: `docker-compose.yml`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `PROGRESS.md`

**Interfaces:**
- Consumes: Host Docker engine & XRDP on `127.0.0.1:3389`
- Produces: Guacamole web service listening on `127.0.0.1:8080` and `guacd` daemon on internal Docker network

- [ ] **Step 1: Create `.gitignore` to prevent secret leakage**
- [ ] **Step 2: Create `.env.example` with template variables**
- [ ] **Step 3: Define `docker-compose.yml` with `guacamole`, `guacd`, and `postgres` services**
- [ ] **Step 4: Initialize `PROGRESS.md` tracking all deployment milestones**
- [ ] **Step 5: Verify configuration validity with `docker compose config`**
- [ ] **Step 6: Commit changes**

---

### Task 2: Database Initialization & Automated Setup Scripts

**Files:**
- Create: `scripts/init-database.sh`
- Create: `scripts/healthcheck.sh`

**Interfaces:**
- Consumes: Apache Guacamole Docker image schema generator (`/opt/guacamole/bin/initdb.sh`)
- Produces: Initialized PostgreSQL database with required schema, default admin user, and pre-configured RDP connection to `host.docker.internal:3389`

- [ ] **Step 1: Write `scripts/init-database.sh` to extract schema and seed PostgreSQL**
- [ ] **Step 2: Write `scripts/healthcheck.sh` to verify service readiness (guacd, web client, postgres)**
- [ ] **Step 3: Grant executable permissions to all scripts**
- [ ] **Step 4: Execute database initialization and bring up the Docker Compose stack**
- [ ] **Step 5: Run healthcheck to verify `127.0.0.1:8080/guacamole/` responds with HTTP 200**
- [ ] **Step 6: Commit changes**

---

### Task 3: Cloudflare Tunnel Integration & Systemd Service

**Files:**
- Create: `scripts/setup-tunnel.sh`
- Create: `systemd/cloudflared-vm-access.service`

**Interfaces:**
- Consumes: `/home/ubuntu/.cf_env` credentials and Cloudflare API
- Produces: Active named Cloudflare Tunnel routing `desktop.intelqong.link` to `http://127.0.0.1:8080/guacamole/`

- [ ] **Step 1: Write `scripts/setup-tunnel.sh` to provision tunnel, DNS CNAME, and tunnel configuration**
- [ ] **Step 2: Create systemd unit template for persistent background execution**
- [ ] **Step 3: Test tunnel connectivity and edge ingress routing**
- [ ] **Step 4: Commit changes**

---

### Task 4: Firewall Hardening & UFW Script

**Files:**
- Create: `scripts/secure-firewall.sh`

**Interfaces:**
- Consumes: System UFW rules
- Produces: Hardened firewall configuration where public inbound ports are minimized or closed

- [ ] **Step 1: Write `scripts/secure-firewall.sh` with safe checks ensuring loopback, local docker, and SSH safety**
- [ ] **Step 2: Commit changes**

---

### Task 5: Professional README & Technical Documentation

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: Architecture, setup procedures, and Cloudflare Access security configurations
- Produces: Executive, production-grade GitHub documentation with badges, architecture flow, step-by-step setup, Cloudflare Access 2FA guide, and troubleshooting

- [ ] **Step 1: Draft high-end, comprehensive `README.md` with system diagrams and detailed guides**
- [ ] **Step 2: Review formatting, links, and code snippets**
- [ ] **Step 3: Commit changes**

---

### Task 6: GitHub Repository Creation & SSH Push

**Files:**
- Modify: `PROGRESS.md` (mark completed)
- Remote: `git@github.com:intelQong/vm-access-anywhere.git`

**Interfaces:**
- Consumes: GitHub CLI (`gh`) and existing SSH key authentication
- Produces: Live public/private repository on GitHub with all commits pushed

- [ ] **Step 1: Check git status and staging**
- [ ] **Step 2: Create remote repository `intelQong/vm-access-anywhere` via `gh`**
- [ ] **Step 3: Push `main` branch to GitHub over SSH**
- [ ] **Step 4: Verify remote repository state and URL**

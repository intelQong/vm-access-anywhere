#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# init-database.sh
# Extracts Apache Guacamole's official PostgreSQL schema and seeds the database.
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
    if [[ -f .env.example ]]; then
        echo "[*] Generating .env from .env.example with a random secure password..."
        cp .env.example .env
        RANDOM_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
        sed -i "s/CHANGE_ME_TO_A_SECURE_RANDOM_PASSWORD/${RANDOM_PASS}/g" .env
        echo "[+] .env generated successfully."
    else
        echo "[-] Error: Neither .env nor .env.example was found."
        exit 1
    fi
fi

# Load variables
source .env

# Detect docker command privileges
if ! docker ps >/dev/null 2>&1; then
    if sudo -n docker ps >/dev/null 2>&1; then
        DOCKER="sudo docker"
        COMPOSE="sudo docker compose"
    else
        echo "[-] Docker permission denied. Add user to docker group or run with sudo."
        exit 1
    fi
else
    DOCKER="docker"
    COMPOSE="docker compose"
fi

echo "[*] Pulling Guacamole images..."
${COMPOSE} pull

echo "[*] Generating PostgreSQL schema from official guacamole/guacamole image..."
SCHEMA_FILE="${ROOT_DIR}/initdb.sql"
${DOCKER} run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > "${SCHEMA_FILE}"
echo "[+] Schema generated at ${SCHEMA_FILE}."

echo "[*] Starting PostgreSQL database container..."
${COMPOSE} up -d postgres

echo "[*] Waiting for PostgreSQL to be ready..."
until ${COMPOSE} exec -T postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; do
    echo "    Waiting for postgres..."
    sleep 2
done
echo "[+] PostgreSQL is ready."

echo "[*] Applying schema to ${POSTGRES_DB}..."
# Check if tables already exist
TABLE_COUNT=$(${COMPOSE} exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d '[:space:]')

if [[ "${TABLE_COUNT}" -gt 0 ]]; then
    echo "[!] Guacamole tables already exist (${TABLE_COUNT} tables found). Skipping re-initialization."
else
    ${COMPOSE} exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" < "${SCHEMA_FILE}"
    echo "[+] Guacamole schema successfully loaded."
fi

# Clean up temporary schema file
rm -f "${SCHEMA_FILE}"

echo "[*] Starting all Guacamole services..."
${COMPOSE} up -d

echo ""
echo "=================================================================="
echo " [SUCCESS] Apache Guacamole stack is running!"
echo " Local URL : http://127.0.0.1:8080/guacamole/"
echo " Default User : guacadmin"
echo " Default Pass : guacadmin (Change immediately on first login!)"
echo "=================================================================="

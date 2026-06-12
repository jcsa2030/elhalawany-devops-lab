#!/bin/bash

set +e

echo "====================================="
echo "Starting Enterprise DevSecOps Lab"
echo "====================================="

PROJECT_DIR="$HOME/node-app"

echo ""
echo "[1/7] Resetting Docker Desktop if needed..."

osascript -e 'quit app "Docker"' 2>/dev/null || true
pkill -f Docker 2>/dev/null || true
pkill -f com.docker 2>/dev/null || true

sleep 10

echo ""
echo "[2/7] Starting Docker Desktop..."
open -a Docker

echo ""
echo "Waiting for Docker Engine..."

MAX_WAIT=180
WAITED=0

until docker info >/dev/null 2>&1
do
    sleep 5
    WAITED=$((WAITED + 5))
    echo "Waiting for Docker Engine... ${WAITED}s"

    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        echo "Docker did not start normally. Trying unattended startup..."
        /Applications/Docker.app/Contents/MacOS/Docker --unattended >/dev/null 2>&1 &
        sleep 20
        break
    fi
done

WAITED=0

until docker info >/dev/null 2>&1
do
    sleep 5
    WAITED=$((WAITED + 5))
    echo "Second wait for Docker Engine... ${WAITED}s"

    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        echo "ERROR: Docker Engine is still not running."
        echo "Please open Docker Desktop manually and wait until it says Docker is running."
        exit 1
    fi
done

echo ""
echo "Docker Engine is running."

echo ""
echo "[3/7] Setting Docker context..."
docker context use desktop-linux >/dev/null 2>&1 || true

echo ""
echo "[4/7] Starting DevSecOps Application Stack..."
cd "$PROJECT_DIR" || exit 1
docker compose up -d

echo ""
echo "[5/7] Starting SonarQube..."
docker start sonarqube 2>/dev/null || echo "SonarQube container not found or already running."

echo ""
echo "[6/7] Starting Dependency-Track..."
docker start dependency-track-postgres 2>/dev/null || echo "Dependency-Track PostgreSQL not found or already running."
docker start dependency-track 2>/dev/null || echo "Dependency-Track API not found or already running."
docker start dependency-track-frontend 2>/dev/null || echo "Dependency-Track Frontend not found or already running."

echo ""
echo "[7/7] Verifying Services..."
sleep 20

echo ""
echo "====================================="
echo "Container Status"
echo "====================================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "====================================="
echo "Health Checks"
echo "====================================="

echo ""
echo "Application:"
curl -s http://localhost:8080/health || echo "Application not ready"

echo ""
echo ""
echo "NIST API:"
curl -s http://localhost:8080/api/nist-summary || echo "NIST API not ready"

echo ""
echo ""
echo "OWASP API:"
curl -s http://localhost:8080/api/owasp-summary || echo "OWASP API not ready"

echo ""
echo ""
echo "Dependency-Track API:"
curl -s http://localhost:8085/api/version || echo "Dependency-Track API not ready"

echo ""
echo ""
echo "====================================="
echo "URLs"
echo "====================================="
echo "Application      : http://localhost:8080"
echo "Jenkins          : http://localhost:8081"
echo "SonarQube        : http://localhost:9000"
echo "Dependency-Track : http://localhost:8086"
echo "====================================="
echo "Startup Complete"
echo "====================================="

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
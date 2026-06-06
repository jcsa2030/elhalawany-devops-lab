#!/bin/bash

set +e

echo "====================================="
echo "Stopping Enterprise DevSecOps Lab"
echo "====================================="

PROJECT_DIR="$HOME/node-app"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$HOME/devsecops-shutdown-logs/$DATE"

mkdir -p "$BACKUP_DIR"

echo ""
echo "[1/8] Saving container status..."
docker ps -a > "$BACKUP_DIR/docker-containers-before-stop.txt" 2>/dev/null || true
docker images > "$BACKUP_DIR/docker-images.txt" 2>/dev/null || true

echo ""
echo "[2/8] Saving important logs..."
docker logs elhalawany-app --tail 200 > "$BACKUP_DIR/elhalawany-app.log" 2>&1 || true
docker logs elhalawany-nginx --tail 200 > "$BACKUP_DIR/elhalawany-nginx.log" 2>&1 || true
docker logs sonarqube --tail 200 > "$BACKUP_DIR/sonarqube.log" 2>&1 || true
docker logs dependency-track --tail 200 > "$BACKUP_DIR/dependency-track-api.log" 2>&1 || true
docker logs dependency-track-frontend --tail 200 > "$BACKUP_DIR/dependency-track-frontend.log" 2>&1 || true
docker logs dependency-track-postgres --tail 200 > "$BACKUP_DIR/dependency-track-postgres.log" 2>&1 || true

echo ""
echo "[3/8] Checking Git status..."
cd "$PROJECT_DIR" || exit 1
git status > "$BACKUP_DIR/git-status.txt" 2>&1 || true
git branch > "$BACKUP_DIR/git-branches.txt" 2>&1 || true
git log --oneline -20 > "$BACKUP_DIR/git-log.txt" 2>&1 || true

echo ""
echo "[4/8] Stopping application Docker Compose stack..."
docker compose down --remove-orphans || true

echo ""
echo "[5/8] Stopping SonarQube..."
docker stop sonarqube 2>/dev/null || true

echo ""
echo "[6/8] Stopping Dependency-Track..."
docker stop dependency-track-frontend 2>/dev/null || true
docker stop dependency-track 2>/dev/null || true
docker stop dependency-track-postgres 2>/dev/null || true

echo ""
echo "[7/8] Final Docker status..."
docker ps -a > "$BACKUP_DIR/docker-containers-after-stop.txt" 2>/dev/null || true

echo ""
echo "[8/8] Shutdown summary..."
echo "Shutdown logs saved in:"
echo "$BACKUP_DIR"

echo ""
echo "====================================="
echo "DevSecOps Lab stopped safely"
echo "You can now shut down your laptop"
echo "====================================="

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
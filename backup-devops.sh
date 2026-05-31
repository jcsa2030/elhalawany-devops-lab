#!/bin/bash

#############################################
# Enterprise DevSecOps Full Backup Script
# Author: Mohamed Elhalawany
#############################################

set -e

DATE=$(date +"%Y-%m-%d_%H-%M-%S")

BACKUP_ROOT="$HOME/devsecops-backups"
BACKUP_DIR="$BACKUP_ROOT/backup_$DATE"

PROJECT_DIR="$HOME/node-app"

echo "========================================="
echo "Enterprise DevSecOps Backup Started"
echo "Date: $DATE"
echo "========================================="

mkdir -p "$BACKUP_DIR"

echo "[1/18] Backing up source code..."
mkdir -p "$BACKUP_DIR/source-code"
cp -R "$PROJECT_DIR" "$BACKUP_DIR/source-code/"

echo "[2/18] Backing up Jenkinsfile..."
mkdir -p "$BACKUP_DIR/jenkins"
cp "$PROJECT_DIR/Jenkinsfile" "$BACKUP_DIR/jenkins/" 2>/dev/null || true

echo "[3/18] Backing up environment files..."
mkdir -p "$BACKUP_DIR/env-files"
cp "$PROJECT_DIR"/.env* "$BACKUP_DIR/env-files/" 2>/dev/null || true

echo "[4/18] Backing up Docker configuration..."
mkdir -p "$BACKUP_DIR/docker"
cp "$PROJECT_DIR/docker-compose.yml" "$BACKUP_DIR/docker/" 2>/dev/null || true
cp "$PROJECT_DIR/Dockerfile" "$BACKUP_DIR/docker/" 2>/dev/null || true
docker ps -a > "$BACKUP_DIR/docker/docker-containers.txt" 2>/dev/null || true
docker images > "$BACKUP_DIR/docker/docker-images.txt" 2>/dev/null || true
docker volume ls > "$BACKUP_DIR/docker/docker-volumes.txt" 2>/dev/null || true
docker network ls > "$BACKUP_DIR/docker/docker-networks.txt" 2>/dev/null || true

echo "[5/18] Backing up security reports..."
mkdir -p "$BACKUP_DIR/security-reports"
cp -R "$PROJECT_DIR/security-reports" "$BACKUP_DIR/" 2>/dev/null || true
cp -R "$PROJECT_DIR/zap-reports" "$BACKUP_DIR/" 2>/dev/null || true

echo "[6/18] Backing up compliance files..."
mkdir -p "$BACKUP_DIR/compliance"
cp -R "$PROJECT_DIR/compliance" "$BACKUP_DIR/" 2>/dev/null || true

echo "[7/18] Backing up monitoring configs..."
mkdir -p "$BACKUP_DIR/monitoring"
cp -R "$PROJECT_DIR/monitoring" "$BACKUP_DIR/" 2>/dev/null || true

echo "[8/18] Backing up operational scripts..."
mkdir -p "$BACKUP_DIR/scripts"
cp "$PROJECT_DIR"/start-devsecops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_DIR"/stop-devsecops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_DIR"/devsecops-ops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_DIR"/backup-devsecops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true

echo "[9/18] Backing up Git information..."
mkdir -p "$BACKUP_DIR/git"
git -C "$PROJECT_DIR" status > "$BACKUP_DIR/git/git-status.txt" 2>/dev/null || true
git -C "$PROJECT_DIR" branch -a > "$BACKUP_DIR/git/branches.txt" 2>/dev/null || true
git -C "$PROJECT_DIR" log --oneline -30 > "$BACKUP_DIR/git/git-log.txt" 2>/dev/null || true
git -C "$PROJECT_DIR" remote -v > "$BACKUP_DIR/git/remotes.txt" 2>/dev/null || true

echo "[10/18] Backing up application PostgreSQL database..."
mkdir -p "$BACKUP_DIR/databases"
docker exec elhalawany-postgres pg_dump -U devopsuser devopsdb \
> "$BACKUP_DIR/databases/elhalawany-devopsdb.sql" 2>/dev/null || true

echo "[11/18] Backing up Dependency-Track PostgreSQL database..."
docker exec dependency-track-postgres pg_dump -U dtrack dtrack \
> "$BACKUP_DIR/databases/dependency-track-db.sql" 2>/dev/null || true

echo "[12/18] Saving Redis snapshot..."
mkdir -p "$BACKUP_DIR/redis"
docker exec elhalawany-redis redis-cli SAVE 2>/dev/null || true
docker cp elhalawany-redis:/data/dump.rdb "$BACKUP_DIR/redis/dump.rdb" 2>/dev/null || true

echo "[13/18] Backing up Grafana database..."
mkdir -p "$BACKUP_DIR/grafana"
docker cp grafana:/var/lib/grafana/grafana.db "$BACKUP_DIR/grafana/grafana.db" 2>/dev/null || true

echo "[14/18] Backing up Prometheus data..."
mkdir -p "$BACKUP_DIR/prometheus"
docker cp prometheus:/prometheus "$BACKUP_DIR/prometheus/data" 2>/dev/null || true

echo "[15/18] Backing up AlertManager data..."
mkdir -p "$BACKUP_DIR/alertmanager"
docker cp alertmanager:/alertmanager "$BACKUP_DIR/alertmanager/data" 2>/dev/null || true

echo "[16/18] Saving monitoring container status..."
docker ps -a | grep -E "prometheus|grafana|cadvisor|node-exporter|blackbox|alertmanager" \
> "$BACKUP_DIR/monitoring/monitoring-containers.txt" 2>/dev/null || true

echo "[17/18] Security check for exposed Slack webhooks..."
mkdir -p "$BACKUP_DIR/security-checks"
grep -R "hooks.slack.com" "$PROJECT_DIR" \
> "$BACKUP_DIR/security-checks/slack-webhook-scan.txt" 2>/dev/null || true

if grep -q "hooks.slack.com" "$BACKUP_DIR/security-checks/slack-webhook-scan.txt" 2>/dev/null; then
    echo "WARNING: Slack webhook found in project files."
    echo "Review: $BACKUP_DIR/security-checks/slack-webhook-scan.txt"
else
    echo "No Slack webhook found in project files."
fi

echo "[18/18] Compressing backup..."
cd "$BACKUP_ROOT"
tar -czf "backup_$DATE.tar.gz" "backup_$DATE"

echo "========================================="
echo "Backup Completed Successfully"
echo "========================================="
echo "Backup Folder:"
echo "$BACKUP_DIR"
echo ""
echo "Compressed Backup:"
echo "$BACKUP_ROOT/backup_$DATE.tar.gz"
echo "========================================="

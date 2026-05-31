#!/bin/bash

#########################################################
# Enterprise DevSecOps Full Backup & Snapshot Script
# Author: Mohamed Elhalawany
#########################################################

set +e

PROJECT_DIR="$HOME/node-app"
BACKUP_ROOT="$HOME/devsecops-full-backups"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$BACKUP_ROOT/full_backup_$DATE"

echo "=================================================="
echo "Enterprise DevSecOps Full Backup Started"
echo "Date: $DATE"
echo "Backup Path: $BACKUP_DIR"
echo "=================================================="

mkdir -p "$BACKUP_DIR"

echo "[1/15] Saving Git information..."
mkdir -p "$BACKUP_DIR/git"
cd "$PROJECT_DIR" || exit 1
git status > "$BACKUP_DIR/git/git-status.txt" 2>&1
git branch -a > "$BACKUP_DIR/git/git-branches.txt" 2>&1
git log --oneline -50 > "$BACKUP_DIR/git/git-log.txt" 2>&1
git remote -v > "$BACKUP_DIR/git/git-remotes.txt" 2>&1

echo "[2/15] Backing up source code..."
cp -R "$PROJECT_DIR" "$BACKUP_DIR/node-app"

echo "[3/15] Backing up Jenkins home..."
cp -R "$HOME/.jenkins" "$BACKUP_DIR/jenkins-home" 2>/dev/null || true

echo "[4/15] Backing up Docker state..."
mkdir -p "$BACKUP_DIR/docker"
docker ps -a > "$BACKUP_DIR/docker/docker-containers.txt" 2>&1
docker images > "$BACKUP_DIR/docker/docker-images.txt" 2>&1
docker volume ls > "$BACKUP_DIR/docker/docker-volumes.txt" 2>&1
docker network ls > "$BACKUP_DIR/docker/docker-networks.txt" 2>&1

echo "[5/15] Backing up application PostgreSQL database..."
mkdir -p "$BACKUP_DIR/databases"
docker exec elhalawany-postgres \
pg_dump -U devopsuser devopsdb \
> "$BACKUP_DIR/databases/elhalawany-devopsdb.sql" 2>/dev/null || true

echo "[6/15] Backing up Dependency-Track PostgreSQL database..."
docker exec dependency-track-postgres \
pg_dump -U dtrack dtrack \
> "$BACKUP_DIR/databases/dependency-track-db.sql" 2>/dev/null || true

echo "[7/15] Saving Redis snapshot..."
mkdir -p "$BACKUP_DIR/redis"
docker exec elhalawany-redis redis-cli SAVE 2>/dev/null || true
docker cp elhalawany-redis:/data/dump.rdb "$BACKUP_DIR/redis/dump.rdb" 2>/dev/null || true

echo "[8/15] Backing up monitoring configuration..."
mkdir -p "$BACKUP_DIR/monitoring"
cp -R "$PROJECT_DIR/monitoring" "$BACKUP_DIR/" 2>/dev/null || true

echo "[9/15] Backing up Grafana database..."
mkdir -p "$BACKUP_DIR/grafana"
docker cp grafana:/var/lib/grafana/grafana.db \
"$BACKUP_DIR/grafana/grafana.db" 2>/dev/null || true

echo "[10/15] Backing up Prometheus data..."
mkdir -p "$BACKUP_DIR/prometheus"
docker cp prometheus:/prometheus \
"$BACKUP_DIR/prometheus/data" 2>/dev/null || true

echo "[11/15] Backing up AlertManager data..."
mkdir -p "$BACKUP_DIR/alertmanager"
docker cp alertmanager:/alertmanager \
"$BACKUP_DIR/alertmanager/data" 2>/dev/null || true

echo "[12/15] Backing up security reports and SBOM..."
mkdir -p "$BACKUP_DIR/security"
cp -R "$PROJECT_DIR/security-reports" "$BACKUP_DIR/security/" 2>/dev/null || true
cp -R "$PROJECT_DIR/zap-reports" "$BACKUP_DIR/security/" 2>/dev/null || true
cp -R "$PROJECT_DIR/compliance" "$BACKUP_DIR/security/" 2>/dev/null || true

echo "[13/15] Backing up operational scripts..."
mkdir -p "$BACKUP_DIR/scripts"
cp "$PROJECT_DIR"/start-devsecops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_DIR"/stop-devsecops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_DIR"/backup-devsecops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_DIR"/devsecops-ops.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true

echo "[14/15] Security check for exposed Slack webhooks..."
mkdir -p "$BACKUP_DIR/security-checks"
grep -R "hooks.slack.com" "$PROJECT_DIR" \
> "$BACKUP_DIR/security-checks/slack-webhook-scan.txt" 2>/dev/null || true

if grep -q "hooks.slack.com" "$BACKUP_DIR/security-checks/slack-webhook-scan.txt" 2>/dev/null; then
    echo "WARNING: Slack webhook found in project files."
    echo "Review: $BACKUP_DIR/security-checks/slack-webhook-scan.txt"
else
    echo "No Slack webhook found in project files."
fi

echo "[15/15] Compressing full backup..."
cd "$BACKUP_ROOT" || exit 1
tar -czf "full_backup_$DATE.tar.gz" "full_backup_$DATE"

echo "=================================================="
echo "Enterprise DevSecOps Full Backup Completed"
echo "Backup Folder:"
echo "$BACKUP_DIR"
echo ""
echo "Compressed Backup:"
echo "$BACKUP_ROOT/full_backup_$DATE.tar.gz"
echo "=================================================="
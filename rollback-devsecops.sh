#!/bin/bash

#############################################
# Enterprise DevSecOps Rollback Script
# Author: Dr. Eng. Mohamed Elhalawany
# Purpose: Roll back application deployment to a previous GHCR release
#############################################

set -e

APP_NAME="elhalawany-devops-lab"
GHCR_IMAGE="ghcr.io/jcsa2030/elhalawany-devops-lab"
LOCAL_FALLBACK_IMAGE="elhalawany-devops-app:latest"
COMPOSE_FILE="docker-compose.yml"

echo "=============================================="
echo "Enterprise DevSecOps Rollback"
echo "Application: $APP_NAME"
echo "=============================================="

if [ -z "$1" ]; then
    echo "ERROR: Please provide release version."
    echo ""
    echo "Example:"
    echo "./rollback-devsecops.sh v1.0.1-devsecops-lab"
    echo "./rollback-devsecops.sh v1.0.0-devsecops-lab"
    exit 1
fi

ROLLBACK_VERSION="$1"
ROLLBACK_IMAGE="$GHCR_IMAGE:$ROLLBACK_VERSION"

echo "Rollback target:"
echo "$ROLLBACK_IMAGE"
echo ""

echo "[1/7] Checking Docker availability..."
docker --version >/dev/null

echo "[2/7] Checking Docker Compose availability..."
docker compose version >/dev/null

echo "[3/7] Pulling rollback image from GHCR..."
if docker pull "$ROLLBACK_IMAGE"; then
    echo "Rollback image pulled successfully."
    export APP_IMAGE="$ROLLBACK_IMAGE"
else
    echo "WARNING: Failed to pull rollback image from GHCR."
    echo "Falling back to local image: $LOCAL_FALLBACK_IMAGE"
    export APP_IMAGE="$LOCAL_FALLBACK_IMAGE"
fi

echo "[4/7] Stopping current application stack..."
docker compose -f "$COMPOSE_FILE" down --remove-orphans || true

echo "[5/7] Starting application stack using:"
echo "$APP_IMAGE"
docker compose -f "$COMPOSE_FILE" up -d

echo "[6/7] Waiting for services to become ready..."
sleep 20

echo "[7/7] Running health checks..."

echo "Checking main health endpoint..."
curl -f http://localhost:8080/health

echo ""
echo "Checking customers API..."
curl -f http://localhost:8080/api/customers

echo ""
echo "=============================================="
echo "Rollback completed successfully"
echo "Active image:"
docker inspect elhalawany-app --format='{{.Config.Image}}' || true
echo "=============================================="

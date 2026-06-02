#!/bin/bash

set -e

FILE="Jenkinsfile"
BACKUP_DIR="backups/jenkinsfile"

echo "Creating Jenkinsfile backup..."

if [ ! -f "$FILE" ]; then
  echo "ERROR: Jenkinsfile not found"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="$BACKUP_DIR/Jenkinsfile.$TIMESTAMP.bak"

cp "$FILE" "$BACKUP_FILE"

echo "Backup created:"
echo "$BACKUP_FILE"

echo ""
echo "Latest backups:"
ls -lt "$BACKUP_DIR" | head -10

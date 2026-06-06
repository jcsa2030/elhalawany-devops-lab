#!/bin/bash

set -e

BACKUP_ROOT="$HOME/node-app/backups"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$BACKUP_ROOT/devsecops-backup-$DATE"

NAMESPACE="devsecops-dev"
POSTGRES_DEPLOYMENT="postgres"
POSTGRES_USER="devsecops"
POSTGRES_DB="devsecopsdb"
REDIS_DEPLOYMENT="redis"

echo "Starting DevSecOps Lab Backup..."
echo "Backup directory: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"/{k8s,postgres,redis,terraform,cluster,logs}

echo "1. Backing up Kubernetes namespace resources..."
kubectl get all -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s/all-resources.yaml"
kubectl get configmaps -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s/configmaps.yaml"
kubectl get secrets -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s/secrets.yaml"
kubectl get pvc -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s/pvc.yaml"
kubectl get hpa -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s/hpa.yaml"
kubectl get ingress -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/k8s/ingress.yaml" 2>/dev/null || true

echo "2. Backing up full cluster summary..."
kubectl get nodes -o wide > "$BACKUP_DIR/cluster/nodes.txt"
kubectl get namespaces > "$BACKUP_DIR/cluster/namespaces.txt"
kubectl get all -A -o wide > "$BACKUP_DIR/cluster/all-namespaces.txt"
kubectl top nodes > "$BACKUP_DIR/cluster/top-nodes.txt" 2>/dev/null || true
kubectl top pods -A > "$BACKUP_DIR/cluster/top-pods.txt" 2>/dev/null || true

echo "3. Backing up PostgreSQL database..."
kubectl exec -n "$NAMESPACE" deployment/"$POSTGRES_DEPLOYMENT" -- \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  > "$BACKUP_DIR/postgres/${POSTGRES_DB}.sql"

echo "4. Backing up Redis..."
kubectl exec -n "$NAMESPACE" deployment/"$REDIS_DEPLOYMENT" -- redis-cli SAVE || true

REDIS_POD=$(kubectl get pod -n "$NAMESPACE" -l app=redis -o jsonpath='{.items[0].metadata.name}')

kubectl cp "$NAMESPACE/$REDIS_POD:/data/dump.rdb" "$BACKUP_DIR/redis/dump.rdb" 2>/dev/null || true

echo "5. Backing up Terraform files..."
cp -R "$HOME/node-app/terraform" "$BACKUP_DIR/terraform/terraform-source"

rm -rf "$BACKUP_DIR/terraform/terraform-source/.terraform"
rm -f "$BACKUP_DIR/terraform/terraform-source/"*.tfstate
rm -f "$BACKUP_DIR/terraform/terraform-source/"*.tfstate.backup

echo "6. Backing up Kubernetes manifests from Git project..."
cp -R "$HOME/node-app/k8s" "$BACKUP_DIR/k8s/source-manifests"

echo "7. Backing up important project files..."
cp "$HOME/node-app/Jenkinsfile" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/node-app/package.json" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/node-app/Dockerfile" "$BACKUP_DIR/" 2>/dev/null || true

echo "8. Backing up pod logs..."
for pod in $(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}'); do
  kubectl logs -n "$NAMESPACE" "$pod" --tail=300 > "$BACKUP_DIR/logs/$pod.log" 2>/dev/null || true
done

echo "9. Creating compressed archive..."
cd "$BACKUP_ROOT"
tar -czf "devsecops-backup-$DATE.tar.gz" "devsecops-backup-$DATE"

echo "Backup completed successfully."
echo "Backup folder:"
echo "$BACKUP_DIR"
echo "Compressed file:"
echo "$BACKUP_ROOT/devsecops-backup-$DATE.tar.gz"

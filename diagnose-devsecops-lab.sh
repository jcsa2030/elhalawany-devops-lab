#!/bin/bash

NAMESPACE="devsecops-dev"
PROJECT_DIR="$HOME/node-app"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$PROJECT_DIR/diagnostic-reports"
REPORT_FILE="$REPORT_DIR/diagnostic-report-$DATE.txt"

mkdir -p "$REPORT_DIR"

log() {
  echo -e "$1" | tee -a "$REPORT_FILE"
}

issue() {
  log "❌ ISSUE: $1"
  log "✅ FIX: $2"
  log ""
}

ok() {
  log "✅ OK: $1"
}

log "========================================"
log " DevSecOps Lab Auto Diagnostic Report"
log " Date: $DATE"
log " Namespace: $NAMESPACE"
log "========================================"
log ""

log "1. Cluster Connectivity"
if kubectl get nodes >/dev/null 2>&1; then
  ok "Kubernetes cluster is reachable"
else
  issue "Kubernetes cluster is not reachable" "Start Docker Desktop Kubernetes and check kubectl context."
fi

log "2. Namespace"
if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  ok "Namespace exists"
else
  issue "Namespace missing" "Run: kubectl apply -f k8s/base/namespace.yaml"
fi

log "3. Pods Health"
for app in nginx node-app postgres redis; do
  POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app="$app" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
  READY=$(kubectl get pods -n "$NAMESPACE" -l app="$app" --no-headers 2>/dev/null | awk '{print $2}' | head -1)

  if [[ "$POD_STATUS" == "Running" && "$READY" == "1/1" ]]; then
    ok "$app pod is healthy"
  else
    issue "$app pod unhealthy" "Run: kubectl describe pod -n $NAMESPACE -l app=$app && kubectl logs -n $NAMESPACE deployment/$app"
  fi
done

log "4. PostgreSQL"
if kubectl exec -n "$NAMESPACE" deployment/postgres -- pg_isready -U devsecops >/dev/null 2>&1; then
  ok "PostgreSQL is accepting connections"
else
  issue "PostgreSQL is not accepting connections" "Check postgres-secret, PVC, and logs: kubectl logs -n $NAMESPACE deployment/postgres"
fi

log "5. Redis"
if kubectl exec -n "$NAMESPACE" deployment/redis -- redis-cli ping 2>/dev/null | grep -q PONG; then
  ok "Redis responds with PONG"
else
  issue "Redis is not responding" "Run: kubectl logs -n $NAMESPACE deployment/redis"
fi

log "6. Node.js Environment Variables"
ENV_CHECK=$(kubectl exec -n "$NAMESPACE" deployment/node-app -- printenv | grep -E "POSTGRES_USER|POSTGRES_DB|POSTGRES_HOST|REDIS_HOST" 2>/dev/null)

log "$ENV_CHECK"

if echo "$ENV_CHECK" | grep -q "POSTGRES_USER=devsecops" && echo "$ENV_CHECK" | grep -q "POSTGRES_DB=devsecopsdb"; then
  ok "Node.js DB environment variables are correct"
else
  issue "Node.js DB environment variables are wrong" "Fix k8s/base/node-app.yaml ConfigMap and Secret, then run: kubectl apply -k k8s/base"
fi

log "7. Metrics Server"
if kubectl top nodes >/dev/null 2>&1; then
  ok "Metrics Server is working"
else
  issue "Metrics Server not available" "Install metrics-server and patch it with --kubelet-insecure-tls."
fi

log "8. HPA"
HPA_TARGET=$(kubectl get hpa node-app-hpa -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}')
if [[ "$HPA_TARGET" == *"<unknown>"* || -z "$HPA_TARGET" ]]; then
  issue "HPA target is unknown" "Ensure metrics-server works and node-app has resources.requests.cpu."
else
  ok "HPA is working: $HPA_TARGET"
fi

log "9. Kustomize"
if kubectl kustomize "$PROJECT_DIR/k8s/base" >/dev/null 2>&1; then
  ok "Kustomize build is valid"
else
  issue "Kustomize build failed" "Run: kubectl kustomize k8s/base and fix YAML."
fi

log "10. Terraform"
cd "$PROJECT_DIR/terraform" || exit
if terraform validate >/dev/null 2>&1; then
  ok "Terraform validation passed"
else
  issue "Terraform validation failed" "Run: cd terraform && terraform validate"
fi
cd "$PROJECT_DIR" || exit

log "11. Git Status"
if git status --porcelain | grep -q .; then
  issue "Uncommitted changes exist" "Run: git status, review changes, then git add/commit/push."
else
  ok "Git working tree is clean"
fi

log "12. Application URL Test"
PORT=18083
pkill -f "kubectl port-forward svc/nginx $PORT:80" >/dev/null 2>&1 || true

kubectl port-forward svc/nginx "$PORT":80 -n "$NAMESPACE" >/tmp/devsecops-diagnose-port-forward.log 2>&1 &
PF_PID=$!
sleep 5

if curl --max-time 5 -s "http://localhost:$PORT/health" | grep -q UP; then
  ok "Application health endpoint is UP"
else
  issue "Application health endpoint failed" "Check nginx and node-app logs."
fi

if curl --max-time 5 -s "http://localhost:$PORT/api/db-health" | grep -q UP; then
  ok "Application database health is UP"
else
  issue "Application database health failed" "Check index.js DB config, image rebuild, POSTGRES env vars, and postgres logs."
fi

if curl --max-time 5 -s "http://localhost:$PORT/api/redis-health" | grep -q UP; then
  ok "Application Redis health is UP"
else
  issue "Application Redis health failed" "Check REDIS_HOST=redis and Redis service."
fi

kill "$PF_PID" >/dev/null 2>&1 || true

log ""
log "========================================"
log " Diagnostic Completed"
log " Report saved to:"
log "$REPORT_FILE"
log "========================================"

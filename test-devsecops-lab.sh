#!/bin/bash

NAMESPACE="devsecops-dev"
APP_LOCAL_PORT="18080"
APP_URL="http://localhost:${APP_LOCAL_PORT}"
REPORT_DIR="$HOME/node-app/test-reports"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/devsecops-test-report-$DATE.txt"

mkdir -p "$REPORT_DIR"

PASS=0
FAIL=0
WARN=0

log() {
  echo -e "$1" | tee -a "$REPORT_FILE"
}

pass() {
  PASS=$((PASS+1))
  log "✅ PASS: $1"
}

fail() {
  FAIL=$((FAIL+1))
  log "❌ FAIL: $1"
  log "   Recommendation: $2"
}

warn() {
  WARN=$((WARN+1))
  log "⚠️  WARN: $1"
  log "   Recommendation: $2"
}

log "========================================"
log " DevSecOps Lab Full Validation Report"
log " Date: $DATE"
log " Namespace: $NAMESPACE"
log "========================================"
log ""

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 command exists"
  else
    fail "$1 command not found" "Install $1 before continuing."
  fi
}

check_command kubectl
check_command docker
check_command curl
check_command git

log ""
log "1. Kubernetes Cluster Check"
log "---------------------------"

if kubectl get nodes >/dev/null 2>&1; then
  pass "Kubernetes cluster is reachable"
  kubectl get nodes -o wide | tee -a "$REPORT_FILE"
else
  fail "Kubernetes cluster is not reachable" "Enable Kubernetes in Docker Desktop or fix kubeconfig context."
fi

log ""
log "2. Namespace Check"
log "------------------"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  pass "Namespace $NAMESPACE exists"
else
  fail "Namespace $NAMESPACE missing" "Run: kubectl apply -f k8s/base/namespace.yaml"
fi

log ""
log "3. Pods Check"
log "-------------"

kubectl get pods -n "$NAMESPACE" | tee -a "$REPORT_FILE"

for app in redis postgres node-app nginx; do
  READY=$(kubectl get pods -n "$NAMESPACE" -l app="$app" --no-headers 2>/dev/null | awk '{print $2}' | head -1)
  STATUS=$(kubectl get pods -n "$NAMESPACE" -l app="$app" --no-headers 2>/dev/null | awk '{print $3}' | head -1)

  if [[ "$STATUS" == "Running" && "$READY" == "1/1" ]]; then
    pass "$app pod is Running and Ready"
  else
    fail "$app pod is not healthy" "Run: kubectl describe pod -n $NAMESPACE -l app=$app && kubectl logs -n $NAMESPACE -l app=$app"
  fi
done

log ""
log "4. Services Check"
log "-----------------"

kubectl get svc -n "$NAMESPACE" | tee -a "$REPORT_FILE"

for svc in redis postgres node-app nginx; do
  if kubectl get svc "$svc" -n "$NAMESPACE" >/dev/null 2>&1; then
    pass "Service $svc exists"
  else
    fail "Service $svc missing" "Check k8s/base/$svc.yaml and run: kubectl apply -k k8s/base"
  fi
done

log ""
log "5. PostgreSQL Check"
log "-------------------"

if kubectl exec -n "$NAMESPACE" deployment/postgres -- pg_isready -U devsecops >/dev/null 2>&1; then
  pass "PostgreSQL is accepting connections"
else
  fail "PostgreSQL is not accepting connections" "Check postgres pod logs and verify postgres-secret values."
fi

log ""
log "6. Redis Check"
log "--------------"

if kubectl exec -n "$NAMESPACE" deployment/redis -- redis-cli ping 2>/dev/null | grep -q "PONG"; then
  pass "Redis responded with PONG"
else
  fail "Redis did not respond correctly" "Check Redis pod logs and service DNS."
fi

log ""
log "7. Metrics Server Check"
log "-----------------------"

if kubectl top nodes >/dev/null 2>&1; then
  pass "Metrics Server is working"
  kubectl top pods -n "$NAMESPACE" | tee -a "$REPORT_FILE"
else
  fail "Metrics Server not working" "Install or patch metrics-server with --kubelet-insecure-tls."
fi

log ""
log "8. HPA Check"
log "------------"

kubectl get hpa -n "$NAMESPACE" | tee -a "$REPORT_FILE"

if kubectl get hpa node-app-hpa -n "$NAMESPACE" >/dev/null 2>&1; then
  TARGETS=$(kubectl get hpa node-app-hpa -n "$NAMESPACE" --no-headers | awk '{print $3}')
  if [[ "$TARGETS" == *"<unknown>"* ]]; then
    fail "HPA target is unknown" "Ensure node-app has CPU requests and metrics-server is working."
  else
    pass "HPA is active with target: $TARGETS"
  fi
else
  warn "HPA not found" "Create hpa.yaml and add it to kustomization.yaml."
fi

log ""
log "9. Node.js Resources and Probes Check"
log "-------------------------------------"

if kubectl describe pod -n "$NAMESPACE" -l app=node-app | grep -q "cpu:"; then
  pass "Node.js CPU requests exist"
else
  fail "Node.js CPU requests missing" "Add resources.requests.cpu to k8s/base/node-app.yaml."
fi

if kubectl describe pod -n "$NAMESPACE" -l app=node-app | grep -q "Readiness"; then
  pass "Readiness probe exists"
else
  fail "Readiness probe missing" "Add readinessProbe to node-app container."
fi

if kubectl describe pod -n "$NAMESPACE" -l app=node-app | grep -q "Liveness"; then
  pass "Liveness probe exists"
else
  fail "Liveness probe missing" "Add livenessProbe to node-app container."
fi

log ""
log "10. Application URL Test via Port Forward"
log "-----------------------------------------"

pkill -f "kubectl port-forward svc/nginx $APP_LOCAL_PORT:80" >/dev/null 2>&1 || true

kubectl port-forward svc/nginx "$APP_LOCAL_PORT":80 -n "$NAMESPACE" >/tmp/devsecops-port-forward.log 2>&1 &
PF_PID=$!

sleep 5

if curl -s "$APP_URL/health" | grep -q "UP"; then
  pass "Application health endpoint is UP"
else
  fail "Application health endpoint failed" "Check nginx and node-app logs. Run: kubectl logs -n $NAMESPACE deployment/nginx"
fi

if curl -s "$APP_URL/api/db-health" | grep -qi "UP"; then
  pass "Application can connect to PostgreSQL"
else
  fail "Application database health failed" "Verify POSTGRES_PASSWORD in node-app-secret matches postgres-secret."
fi

if curl -s "$APP_URL/api/redis-health" | grep -qi "UP"; then
  pass "Application can connect to Redis"
else
  fail "Application Redis health failed" "Verify REDIS_HOST=redis and Redis service is running."
fi

if curl -s "$APP_URL/metrics" | grep -q "security_"; then
  pass "Security metrics are exposed"
else
  fail "Security metrics missing" "Check /metrics endpoint in Node.js app."
fi

kill "$PF_PID" >/dev/null 2>&1 || true

log ""
log "11. Kustomize Validation"
log "------------------------"

if kubectl kustomize k8s/base >/dev/null 2>&1; then
  pass "Kustomize build succeeded"
else
  fail "Kustomize build failed" "Run: kubectl kustomize k8s/base and fix YAML errors."
fi

if kubectl apply --dry-run=client -k k8s/base >/dev/null 2>&1; then
  pass "Kubernetes dry-run succeeded"
else
  fail "Kubernetes dry-run failed" "Run: kubectl apply --dry-run=client -k k8s/base"
fi

log ""
log "12. Docker Check"
log "----------------"

if docker ps >/dev/null 2>&1; then
  pass "Docker is running"
else
  warn "Docker is not running or not reachable" "Open Docker Desktop."
fi

log ""
log "13. Terraform Check"
log "-------------------"

if [ -d "$HOME/node-app/terraform" ]; then
  cd "$HOME/node-app/terraform"
  if terraform validate >/dev/null 2>&1; then
    pass "Terraform validate succeeded"
  else
    warn "Terraform validate failed" "Run: cd terraform && terraform validate"
  fi
  cd "$HOME/node-app"
else
  warn "Terraform folder not found" "Check project structure."
fi

log ""
log "14. Recent Logs Summary"
log "-----------------------"

for app in nginx node-app postgres redis; do
  log ""
  log "--- Logs for $app ---"
  kubectl logs -n "$NAMESPACE" deployment/"$app" --tail=20 2>/dev/null | tee -a "$REPORT_FILE" || true
done

log ""
log "========================================"
log " Final Summary"
log "========================================"
log "PASS: $PASS"
log "FAIL: $FAIL"
log "WARN: $WARN"
log ""

if [ "$FAIL" -eq 0 ]; then
  log "✅ Overall Status: HEALTHY"
  log "Recommendation: Lab is ready for next phase."
else
  log "❌ Overall Status: NEEDS FIX"
  log "Recommendation: Fix failed items above before moving forward."
fi

log ""
log "Report saved to:"
log "$REPORT_FILE"

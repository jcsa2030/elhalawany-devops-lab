#!/bin/bash

set -euo pipefail

NAMESPACE="devsecops-dev"
PROJECT_DIR="$HOME/node-app"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$PROJECT_DIR/recovery-reports"
REPORT_FILE="$REPORT_DIR/recovery-report-$DATE.txt"
LOG_DIR="$REPORT_DIR/logs-$DATE"
PORT="18084"

mkdir -p "$REPORT_DIR" "$LOG_DIR"

PASS=0
FAIL=0
WARN=0

log() {
  echo -e "$1" | tee -a "$REPORT_FILE"
}

step() {
  log ""
  log "=================================================="
  log "$1"
  log "=================================================="
}

success() {
  PASS=$((PASS+1))
  log "✅ SUCCESS: $1"
}

failure() {
  FAIL=$((FAIL+1))
  log "❌ FAILED: $1"
  log "Recommendation: $2"
}

warning() {
  WARN=$((WARN+1))
  log "⚠️ WARNING: $1"
  log "Recommendation: $2"
}

run_safe() {
  local description="$1"
  local command="$2"
  local recommendation="${3:-Review the command output and related service logs.}"

  log ""
  log ">>> $description"
  log "Command: $command"

  if eval "$command" >> "$REPORT_FILE" 2>&1; then
    success "$description"
  else
    failure "$description" "$recommendation"
  fi
}

cleanup() {
  pkill -f "kubectl port-forward svc/nginx $PORT:80" >/dev/null 2>&1 || true
}

trap cleanup EXIT

log "=================================================="
log " DevSecOps Lab Recovery Report"
log " Date: $DATE"
log " Namespace: $NAMESPACE"
log " Project: $PROJECT_DIR"
log "=================================================="

step "1. Tooling and Project Checks"

for cmd in kubectl docker git curl terraform; do
  if command -v "$cmd" >/dev/null 2>&1; then
    success "$cmd command exists"
  else
    failure "$cmd command missing" "Install $cmd before running recovery."
  fi
done

if [ -d "$PROJECT_DIR" ]; then
  success "Project directory exists: $PROJECT_DIR"
else
  failure "Project directory missing" "Verify PROJECT_DIR path in the script."
  exit 1
fi

cd "$PROJECT_DIR"

step "2. Cluster and Namespace Pre-Check"

run_safe "Check Kubernetes nodes" \
  "kubectl get nodes -o wide" \
  "Start Docker Desktop Kubernetes or fix kubectl context."

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  success "Namespace $NAMESPACE exists"
else
  warning "Namespace $NAMESPACE does not exist" "The script will try to recreate it using k8s/base."
fi

run_safe "Check current namespace resources" \
  "kubectl get all -n $NAMESPACE -o wide || true" \
  "Namespace may be missing or resources may not be deployed."

run_safe "Check PVC" \
  "kubectl get pvc -n $NAMESPACE || true" \
  "If PVC is missing, PostgreSQL data may not be persistent."

run_safe "Check HPA" \
  "kubectl get hpa -n $NAMESPACE || true" \
  "If HPA is missing, apply k8s/base/hpa.yaml."

step "3. Stop Existing Port-Forward Sessions"

run_safe "Stop old kubectl port-forward sessions" \
  "pkill -f 'kubectl port-forward' || true" \
  "If port-forward remains stuck, find it using: lsof -i :$PORT"

step "4. Validate Kubernetes Manifests"

if [ -d "$PROJECT_DIR/k8s/base" ]; then
  success "Kubernetes base manifests folder exists"
else
  failure "k8s/base folder missing" "Restore k8s/base from Git before recovery."
fi

run_safe "Kustomize build validation" \
  "kubectl kustomize k8s/base >/tmp/devsecops-recovery-kustomize.yaml" \
  "Run: kubectl kustomize k8s/base and fix YAML or kustomization errors."

run_safe "Kubernetes dry-run validation" \
  "kubectl apply --dry-run=client -k k8s/base" \
  "Run: kubectl apply --dry-run=client -k k8s/base and fix validation errors."

step "5. Reapply Desired Kubernetes State"

run_safe "Apply Kubernetes manifests" \
  "kubectl apply -k k8s/base" \
  "Fix manifest errors. If immutable selector error appears, delete only the affected Deployment and reapply."

step "6. Restart Core Deployments Safely"

for deploy in redis postgres node-app nginx; do
  if kubectl get deployment "$deploy" -n "$NAMESPACE" >/dev/null 2>&1; then
    run_safe "Restart deployment $deploy" \
      "kubectl rollout restart deployment/$deploy -n $NAMESPACE" \
      "Check deployment exists and namespace is correct."

    run_safe "Wait for deployment $deploy rollout" \
      "kubectl rollout status deployment/$deploy -n $NAMESPACE --timeout=180s" \
      "Run: kubectl describe deployment $deploy -n $NAMESPACE && kubectl logs -n $NAMESPACE deployment/$deploy"
  else
    warning "Deployment $deploy not found" \
      "Run: kubectl apply -k k8s/base, then check k8s/base/$deploy.yaml."
  fi
done

step "7. Deployment Readiness Verification"

for deploy in redis postgres node-app nginx; do
  run_safe "Verify deployment $deploy availability" \
    "kubectl get deployment $deploy -n $NAMESPACE" \
    "Deployment $deploy is missing. Check manifests and reapply."

  run_safe "Check rollout status for $deploy" \
    "kubectl rollout status deployment/$deploy -n $NAMESPACE --timeout=180s" \
    "Deployment $deploy did not become ready. Check describe and logs."
done

run_safe "Show pods after recovery" \
  "kubectl get pods -n $NAMESPACE -o wide" \
  "Review pod status. Any CrashLoopBackOff or Pending pod must be investigated."

step "8. PostgreSQL Recovery Validation"

run_safe "Check PostgreSQL readiness" \
  "kubectl exec -n $NAMESPACE deployment/postgres -- pg_isready -U devsecops" \
  "Check postgres pod logs, postgres-secret, PVC, and POSTGRES_USER."

run_safe "Check PostgreSQL database list" \
  "kubectl exec -n $NAMESPACE deployment/postgres -- psql -U devsecops -d devsecopsdb -c '\\l'" \
  "Check POSTGRES_DB value and whether PVC was initialized with older credentials."

run_safe "Check PostgreSQL role list" \
  "kubectl exec -n $NAMESPACE deployment/postgres -- psql -U devsecops -d devsecopsdb -c '\\du'" \
  "If role devsecops is missing, recreate PostgreSQL PVC or create the role manually."

step "9. Redis Recovery Validation"

run_safe "Check Redis PING" \
  "kubectl exec -n $NAMESPACE deployment/redis -- redis-cli ping" \
  "Check Redis pod logs and Redis service."

run_safe "Check Redis INFO summary" \
  "kubectl exec -n $NAMESPACE deployment/redis -- redis-cli INFO server | head -20" \
  "Redis is running but INFO failed. Check redis-cli availability."

step "10. Node.js Runtime and Connectivity Validation"

run_safe "Check Node.js POSTGRES environment" \
  "kubectl exec -n $NAMESPACE deployment/node-app -- printenv | grep POSTGRES" \
  "Fix k8s/base/node-app.yaml ConfigMap or Secret."

run_safe "Check Node.js REDIS environment" \
  "kubectl exec -n $NAMESPACE deployment/node-app -- printenv | grep REDIS" \
  "Fix k8s/base/node-app.yaml ConfigMap."

run_safe "Check network connectivity from Node.js to PostgreSQL" \
  "kubectl exec -n $NAMESPACE deployment/node-app -- sh -c 'nc -zv postgres 5432'" \
  "Check PostgreSQL service, DNS, and NetworkPolicy if any."

run_safe "Check network connectivity from Node.js to Redis" \
  "kubectl exec -n $NAMESPACE deployment/node-app -- sh -c 'nc -zv redis 6379'" \
  "Check Redis service, DNS, and NetworkPolicy if any."

run_safe "Check running image digest for Node.js" \
  "kubectl describe pod -n $NAMESPACE -l app=node-app | grep -i 'Image:'" \
  "If DB config still wrong, rebuild and push the application image."

step "11. Metrics Server and HPA Recovery Validation"

if kubectl top nodes >/dev/null 2>&1; then
  success "Metrics Server is working"
  kubectl top pods -n "$NAMESPACE" | tee -a "$REPORT_FILE" || true
else
  failure "Metrics Server not working" \
    "Install metrics-server and patch with --kubelet-insecure-tls for Docker Desktop."
fi

run_safe "Check HPA status" \
  "kubectl get hpa -n $NAMESPACE" \
  "Apply hpa.yaml and verify node-app has resources.requests.cpu."

HPA_TARGET=$(kubectl get hpa node-app-hpa -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || true)

if [[ "$HPA_TARGET" == *"<unknown>"* || -z "$HPA_TARGET" ]]; then
  failure "HPA target is unknown" \
    "Ensure metrics-server works and node-app has CPU requests."
else
  success "HPA target is active: $HPA_TARGET"
fi

step "12. Application End-to-End Test"

pkill -f "kubectl port-forward svc/nginx $PORT:80" >/dev/null 2>&1 || true

kubectl port-forward svc/nginx "$PORT":80 -n "$NAMESPACE" >/tmp/devsecops-recovery-port-forward.log 2>&1 &
PF_PID=$!

sleep 5

if ps -p "$PF_PID" >/dev/null 2>&1; then
  success "Port-forward started on localhost:$PORT"
else
  failure "Port-forward failed" "Run: cat /tmp/devsecops-recovery-port-forward.log or change PORT variable."
fi

check_url() {
  local name="$1"
  local url="$2"
  local expected="$3"
  local recommendation="$4"

  log ""
  log ">>> Testing $name"
  log "URL: $url"

  RESPONSE=$(curl --max-time 8 -s "$url" || true)

  echo "$RESPONSE" >> "$REPORT_FILE"

  if echo "$RESPONSE" | grep -qi "$expected"; then
    success "$name"
  else
    failure "$name" "$recommendation"
  fi
}

check_url "Application health endpoint" \
  "http://localhost:$PORT/health" \
  "UP" \
  "Check nginx service, nginx config, node-app readiness, and pod logs."

check_url "Application PostgreSQL health endpoint" \
  "http://localhost:$PORT/api/db-health" \
  "UP" \
  "Check index.js DB config, app image rebuild, POSTGRES env vars, postgres logs."

check_url "Application Redis health endpoint" \
  "http://localhost:$PORT/api/redis-health" \
  "UP" \
  "Check REDIS_HOST=redis, Redis service, and Redis pod logs."

check_url "Application security metrics endpoint" \
  "http://localhost:$PORT/metrics" \
  "security_" \
  "Check /metrics endpoint and Prometheus instrumentation."

kill "$PF_PID" >/dev/null 2>&1 || true

step "13. Recent Events Collection"

run_safe "Collect recent namespace events" \
  "kubectl get events -n $NAMESPACE --sort-by=.metadata.creationTimestamp | tail -80" \
  "Review Warning events for scheduling, image pull, readiness, or probe failures."

step "14. Logs Collection"

for app in nginx node-app postgres redis; do
  if kubectl get deployment "$app" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl logs -n "$NAMESPACE" deployment/"$app" --tail=200 > "$LOG_DIR/$app.log" 2>/dev/null || true
    success "Saved logs for $app to $LOG_DIR/$app.log"
  else
    warning "Cannot collect logs for $app" "Deployment $app does not exist."
  fi
done

step "15. Terraform and Docker Validation"

if [ -d "$PROJECT_DIR/terraform" ]; then
  cd "$PROJECT_DIR/terraform"

  run_safe "Terraform fmt check" \
    "terraform fmt -check" \
    "Run: cd terraform && terraform fmt"

  run_safe "Terraform validate" \
    "terraform validate" \
    "Run: cd terraform && terraform validate and fix errors."

  cd "$PROJECT_DIR"
else
  warning "Terraform directory not found" "Check project structure."
fi

run_safe "Docker running containers" \
  "docker ps" \
  "Open Docker Desktop or start Docker Engine."

run_safe "Docker disk usage" \
  "docker system df" \
  "Consider pruning unused images only after backup."

step "16. Git and Repository Hygiene"

run_safe "Git status" \
  "git status" \
  "Review uncommitted changes."

if git status --porcelain | grep -q .; then
  warning "Uncommitted changes detected" \
    "Run git status, review changes, then git add/commit/push."
else
  success "Git working tree is clean"
fi

run_safe "Last five commits" \
  "git log --oneline -5" \
  "Check Git history."

step "17. Optional Full Validation Script"

if [ -f "$PROJECT_DIR/test-devsecops-lab.sh" ]; then
  run_safe "Run full validation script" \
    "$PROJECT_DIR/test-devsecops-lab.sh" \
    "Open latest report under test-reports and fix listed failures."
else
  warning "test-devsecops-lab.sh not found" \
    "Create the validation script before moving to ArgoCD."
fi

step "18. Final Summary"

log "PASS: $PASS"
log "FAIL: $FAIL"
log "WARN: $WARN"
log ""

if [ "$FAIL" -eq 0 ]; then
  log "✅ Overall Recovery Status: HEALTHY"
  log "Recommendation: Lab is ready for the next phase."
else
  log "❌ Overall Recovery Status: NEEDS ATTENTION"
  log "Recommendation: Fix failed items above before moving forward."
fi

log ""
log "Recovery report:"
log "$REPORT_FILE"
log ""
log "Service logs:"
log "$LOG_DIR"


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"

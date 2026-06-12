#!/bin/bash
set -e

PROJECT_DIR="$HOME/node-app"
cd "$PROJECT_DIR"

cat > k8s-release-readiness.sh <<'EOF'
#!/bin/bash
set -e
NS="devsecops-dev"
echo "=== Kubernetes Release Readiness ==="

kubectl get nodes
kubectl get pods -n $NS
kubectl get svc -n $NS
kubectl get hpa -n $NS
kubectl top pods -n $NS || true
kubectl kustomize k8s/base >/dev/null
kubectl apply --dry-run=client -k k8s/base >/dev/null
terraform -chdir=terraform validate

kubectl exec -n $NS deployment/postgres -- pg_isready -U devsecops
kubectl exec -n $NS deployment/redis -- redis-cli ping

PORT=18100
pkill -f "kubectl port-forward svc/nginx $PORT:80" || true
kubectl port-forward svc/nginx $PORT:80 -n $NS >/tmp/release-readiness.log 2>&1 &
PID=$!
sleep 5

curl --max-time 5 -s http://localhost:$PORT/health | grep UP
curl --max-time 5 -s http://localhost:$PORT/api/db-health | grep UP
curl --max-time 5 -s http://localhost:$PORT/api/redis-health | grep UP
curl --max-time 5 -s http://localhost:$PORT/metrics | grep security_

kill $PID || true

if git status --porcelain | grep -q .; then
  echo "WARNING: Git has uncommitted changes"
else
  echo "Git clean"
fi

echo "✅ RELEASE READY"
EOF

cat > k8s-security-audit.sh <<'EOF'
#!/bin/bash
set -e
NS="devsecops-dev"
echo "=== Kubernetes Security Audit ==="

echo "[1] Pods running as root / privileged check"
kubectl get pods -n $NS -o yaml | grep -E "privileged: true|runAsUser: 0" || echo "OK: No obvious privileged/root config found"

echo "[2] Secrets"
kubectl get secrets -n $NS

echo "[3] Services exposure"
kubectl get svc -n $NS
kubectl get svc -n $NS | grep NodePort || echo "OK: No NodePort services"

echo "[4] Resource limits"
kubectl describe pod -n $NS -l app=node-app | grep -A12 "Limits" || echo "WARNING: No limits shown"

echo "[5] Image tags"
kubectl get deployments -n $NS -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.template.spec.containers[*].image}{"\n"}{end}'

echo "[6] RBAC"
kubectl get role,rolebinding,serviceaccount -n $NS

echo "[7] NetworkPolicy"
kubectl get networkpolicy -n $NS || true

echo "✅ Security audit completed"
EOF

cat > k8s-performance-smoke-test.sh <<'EOF'
#!/bin/bash
set -e
NS="devsecops-dev"
PORT=18101
REQUESTS=50

echo "=== Kubernetes Performance Smoke Test ==="

pkill -f "kubectl port-forward svc/nginx $PORT:80" || true
kubectl port-forward svc/nginx $PORT:80 -n $NS >/tmp/perf-smoke.log 2>&1 &
PID=$!
sleep 5

SUCCESS=0
FAIL=0

for i in $(seq 1 $REQUESTS); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:$PORT/health || true)
  if [ "$CODE" = "200" ]; then
    SUCCESS=$((SUCCESS+1))
  else
    FAIL=$((FAIL+1))
  fi
done

kill $PID || true

echo "Requests: $REQUESTS"
echo "Success : $SUCCESS"
echo "Failed  : $FAIL"

kubectl top pods -n $NS || true
kubectl get hpa -n $NS

if [ "$FAIL" -eq 0 ]; then
  echo "✅ Performance smoke test passed"
else
  echo "❌ Performance smoke test failed"
  echo "Recommendation: Check nginx/node-app logs and resource limits."
fi
EOF

cat > k8s-disaster-recovery-drill.sh <<'EOF'
#!/bin/bash
set -e
NS="devsecops-dev"

echo "=== Kubernetes Disaster Recovery Drill ==="

echo "Current pods:"
kubectl get pods -n $NS

for app in node-app nginx redis; do
  POD=$(kubectl get pod -n $NS -l app=$app -o jsonpath='{.items[0].metadata.name}')
  echo "Deleting pod: $POD"
  kubectl delete pod $POD -n $NS
  kubectl rollout status deployment/$app -n $NS --timeout=180s
done

echo "Checking PostgreSQL without deleting data pod..."
kubectl exec -n $NS deployment/postgres -- pg_isready -U devsecops

echo "Final pods:"
kubectl get pods -n $NS

echo "✅ DR drill completed. Kubernetes self-healing confirmed."
EOF

cat > k8s-cleanup-safe.sh <<'EOF'
#!/bin/bash
set -e
PROJECT="$HOME/node-app"

echo "=== Safe Cleanup ==="

echo "Cleaning old reports older than 14 days..."
find "$PROJECT" -type f -path "*/reports/*" -mtime +14 -delete 2>/dev/null || true
find "$PROJECT" -type d -name "logs-*" -mtime +14 -exec rm -rf {} + 2>/dev/null || true

echo "Stopping stale port-forward sessions..."
pkill -f "kubectl port-forward" || true

echo "Docker disk usage before:"
docker system df || true

echo "Pruning stopped containers only..."
docker container prune -f || true

echo "Docker disk usage after:"
docker system df || true

echo "Git status:"
git -C "$PROJECT" status

echo "✅ Safe cleanup completed"
EOF

cat > platform-daily-health.sh <<'EOF'
#!/bin/bash
set -e
NS="devsecops-dev"
PROJECT="$HOME/node-app"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$PROJECT/daily-health-reports"
REPORT="$REPORT_DIR/daily-health-$DATE.txt"
mkdir -p "$REPORT_DIR"

{
echo "=== Daily DevSecOps Platform Health ==="
echo "Date: $DATE"
echo ""

echo "Cluster:"
kubectl get nodes

echo ""
echo "Pods:"
kubectl get pods -n $NS

echo ""
echo "Services:"
kubectl get svc -n $NS

echo ""
echo "HPA:"
kubectl get hpa -n $NS

echo ""
echo "Resources:"
kubectl top pods -n $NS || true

echo ""
echo "PostgreSQL:"
kubectl exec -n $NS deployment/postgres -- pg_isready -U devsecops || true

echo ""
echo "Redis:"
kubectl exec -n $NS deployment/redis -- redis-cli ping || true

echo ""
echo "Git:"
git -C "$PROJECT" status --short

echo ""
echo "Terraform:"
terraform -chdir="$PROJECT/terraform" validate || true

echo ""
echo "Kustomize:"
kubectl apply --dry-run=client -k "$PROJECT/k8s/base" || true

echo ""
echo "Recommendation:"
echo "- If all pods are Running and HPA is not unknown, platform is healthy."
echo "- If DB/Redis fails, run diagnose-devsecops-lab.sh."
echo "- If deployment fails, run recover-devsecops-lab.sh."
} | tee "$REPORT"

echo "Report saved: $REPORT"
EOF

chmod +x \
  k8s-release-readiness.sh \
  k8s-security-audit.sh \
  k8s-performance-smoke-test.sh \
  k8s-disaster-recovery-drill.sh \
  k8s-cleanup-safe.sh \
  platform-daily-health.sh

echo "✅ World-class operations scripts installed."

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
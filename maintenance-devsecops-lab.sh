#!/bin/bash

set -e

NAMESPACE="devsecops-dev"
PROJECT_DIR="$HOME/node-app"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$PROJECT_DIR/maintenance-reports"
REPORT_FILE="$REPORT_DIR/maintenance-report-$DATE.txt"

mkdir -p "$REPORT_DIR"

log() {
  echo -e "$1" | tee -a "$REPORT_FILE"
}

run_step() {
  log ""
  log ">>> $1"
}

log "========================================"
log " DevSecOps Lab Maintenance Report"
log " Date: $DATE"
log " Namespace: $NAMESPACE"
log "========================================"

run_step "1. Kubernetes Cluster Status"
kubectl get nodes -o wide | tee -a "$REPORT_FILE"
kubectl get namespaces | tee -a "$REPORT_FILE"

run_step "2. DevSecOps Namespace Resources"
kubectl get all -n "$NAMESPACE" -o wide | tee -a "$REPORT_FILE"
kubectl get pvc -n "$NAMESPACE" | tee -a "$REPORT_FILE"
kubectl get hpa -n "$NAMESPACE" | tee -a "$REPORT_FILE"

run_step "3. Resource Usage"
kubectl top nodes | tee -a "$REPORT_FILE" || true
kubectl top pods -n "$NAMESPACE" | tee -a "$REPORT_FILE" || true

run_step "4. Restart Unhealthy Pods Only"
for pod in $(kubectl get pods -n "$NAMESPACE" --no-headers | awk '$3!="Running" || $2!="1/1" {print $1}'); do
  log "Restarting unhealthy pod: $pod"
  kubectl delete pod "$pod" -n "$NAMESPACE"
done

run_step "5. Rollout Status"
for deploy in redis postgres node-app nginx; do
  kubectl rollout status deployment/"$deploy" -n "$NAMESPACE" --timeout=120s | tee -a "$REPORT_FILE"
done

run_step "6. Application Health"
kubectl port-forward svc/nginx 18082:80 -n "$NAMESPACE" >/tmp/devsecops-maintenance-port-forward.log 2>&1 &
PF_PID=$!
sleep 5

curl --max-time 5 -s http://localhost:18082/health | tee -a "$REPORT_FILE" || true
echo "" | tee -a "$REPORT_FILE"

curl --max-time 5 -s http://localhost:18082/api/db-health | tee -a "$REPORT_FILE" || true
echo "" | tee -a "$REPORT_FILE"

curl --max-time 5 -s http://localhost:18082/api/redis-health | tee -a "$REPORT_FILE" || true
echo "" | tee -a "$REPORT_FILE"

curl --max-time 5 -s http://localhost:18082/metrics | grep security_ | tee -a "$REPORT_FILE" || true

kill "$PF_PID" >/dev/null 2>&1 || true

run_step "7. Kubernetes Events"
kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | tail -40 | tee -a "$REPORT_FILE"

run_step "8. Pod Logs Snapshot"
mkdir -p "$REPORT_DIR/logs-$DATE"

for app in nginx node-app postgres redis; do
  kubectl logs -n "$NAMESPACE" deployment/"$app" --tail=100 > "$REPORT_DIR/logs-$DATE/$app.log" 2>/dev/null || true
  log "Saved logs for $app"
done

run_step "9. Docker System Status"
docker ps | tee -a "$REPORT_FILE"
docker system df | tee -a "$REPORT_FILE"

run_step "10. Terraform Validation"
cd "$PROJECT_DIR/terraform"
terraform fmt -check | tee -a "$REPORT_FILE" || true
terraform validate | tee -a "$REPORT_FILE" || true
cd "$PROJECT_DIR"

run_step "11. Kustomize Validation"
kubectl kustomize k8s/base >/tmp/kustomize-maintenance.yaml
kubectl apply --dry-run=client -k k8s/base | tee -a "$REPORT_FILE"

run_step "12. Git Status"
git status | tee -a "$REPORT_FILE"
git log --oneline -5 | tee -a "$REPORT_FILE"

run_step "13. Cleanup Old Reports"
find "$REPORT_DIR" -type f -name "*.txt" -mtime +14 -delete || true
find "$REPORT_DIR" -type d -name "logs-*" -mtime +14 -exec rm -rf {} + 2>/dev/null || true

log ""
log "========================================"
log " Maintenance Completed"
log " Report saved to:"
log "$REPORT_FILE"
log "========================================"


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
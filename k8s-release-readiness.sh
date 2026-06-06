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


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"

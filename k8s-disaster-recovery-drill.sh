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

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"


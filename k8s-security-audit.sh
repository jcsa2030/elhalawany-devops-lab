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


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"

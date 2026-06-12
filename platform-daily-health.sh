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


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
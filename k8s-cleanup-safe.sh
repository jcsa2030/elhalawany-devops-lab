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


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
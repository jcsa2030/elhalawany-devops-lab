docker start prometheus 2>/dev/null || true
docker start grafana 2>/dev/null || true
docker start cadvisor 2>/dev/null || true
docker start node-exporter 2>/dev/null || true

source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"
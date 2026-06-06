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


source "$HOME/node-app/ops-html-email-helper.sh"

HTML_FILE="${REPORT_FILE%.txt}.html"

create_html_report "DevSecOps Lab Report" "$REPORT_FILE" "$HTML_FILE"

echo "HTML report:"
echo "$HTML_FILE"

send_email_if_enabled "DevSecOps Lab Report" "$HTML_FILE"

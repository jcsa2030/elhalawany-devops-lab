#!/bin/bash

NAMESPACE="devsecops-dev"
APP_DEPLOYMENT="node-app"
NGINX_DEPLOYMENT="nginx"
POSTGRES_DEPLOYMENT="postgres"
REDIS_DEPLOYMENT="redis"
REPORT_DIR="$HOME/node-app/k8s-admin-reports"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/k8s-admin-report-$DATE.txt"

mkdir -p "$REPORT_DIR"

run_section() {
  echo ""
  echo "=================================================="
  echo "$1"
  echo "=================================================="
}

run_cmd() {
  echo ""
  echo "Command:"
  echo "$1"
  echo ""
  eval "$1" 2>&1
}

{
run_section "Kubernetes Admin Learning Script"
echo "Date: $DATE"
echo "Namespace: $NAMESPACE"
echo ""
echo "Purpose:"
echo "This script collects the most important Kubernetes admin commands."
echo "It helps you understand cluster, namespace, deployments, pods, services, config, secrets, storage, monitoring, autoscaling, rollout, events, and troubleshooting."

run_section "1. Cluster Administration"
echo "Explanation: These commands show whether Kubernetes is working and which nodes are available."
run_cmd "kubectl cluster-info"
run_cmd "kubectl get nodes -o wide"
run_cmd "kubectl describe node \$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

run_section "2. Namespace Administration"
echo "Explanation: Namespaces separate environments such as dev, test, security, and production."
run_cmd "kubectl get namespaces"
run_cmd "kubectl describe namespace $NAMESPACE"

run_section "3. Deployment Administration"
echo "Explanation: Deployments manage application replicas and keep pods running."
run_cmd "kubectl get deployments -n $NAMESPACE"
run_cmd "kubectl describe deployment $APP_DEPLOYMENT -n $NAMESPACE"
run_cmd "kubectl get deployment $APP_DEPLOYMENT -n $NAMESPACE -o yaml"

run_section "4. Pod Administration"
echo "Explanation: Pods are the running containers inside Kubernetes."
run_cmd "kubectl get pods -n $NAMESPACE"
run_cmd "kubectl get pods -o wide -n $NAMESPACE"
run_cmd "kubectl describe pod -n $NAMESPACE -l app=$APP_DEPLOYMENT"

run_section "5. Logs Administration"
echo "Explanation: Logs help you understand application errors and runtime behavior."
run_cmd "kubectl logs deployment/$APP_DEPLOYMENT -n $NAMESPACE --tail=80"
run_cmd "kubectl logs deployment/$NGINX_DEPLOYMENT -n $NAMESPACE --tail=80"
run_cmd "kubectl logs deployment/$POSTGRES_DEPLOYMENT -n $NAMESPACE --tail=80"
run_cmd "kubectl logs deployment/$REDIS_DEPLOYMENT -n $NAMESPACE --tail=80"

run_section "6. Execute Commands Inside Pods"
echo "Explanation: This is similar to SSH into a container."
run_cmd "kubectl exec -n $NAMESPACE deployment/$APP_DEPLOYMENT -- printenv | sort"
run_cmd "kubectl exec -n $NAMESPACE deployment/$APP_DEPLOYMENT -- sh -c 'nc -zv postgres 5432'"
run_cmd "kubectl exec -n $NAMESPACE deployment/$APP_DEPLOYMENT -- sh -c 'nc -zv redis 6379'"
run_cmd "kubectl exec -n $NAMESPACE deployment/$POSTGRES_DEPLOYMENT -- pg_isready -U devsecops"
run_cmd "kubectl exec -n $NAMESPACE deployment/$REDIS_DEPLOYMENT -- redis-cli ping"

run_section "7. Service Administration"
echo "Explanation: Services provide stable network names and ports for pods."
run_cmd "kubectl get svc -n $NAMESPACE"
run_cmd "kubectl describe svc nginx -n $NAMESPACE"
run_cmd "kubectl describe svc node-app -n $NAMESPACE"
run_cmd "kubectl describe svc postgres -n $NAMESPACE"
run_cmd "kubectl describe svc redis -n $NAMESPACE"

run_section "8. ConfigMap Administration"
echo "Explanation: ConfigMaps store non-sensitive configuration."
run_cmd "kubectl get configmaps -n $NAMESPACE"
run_cmd "kubectl get configmap node-app-config -n $NAMESPACE -o yaml"

run_section "9. Secret Administration"
echo "Explanation: Secrets store sensitive values such as passwords. Kubernetes stores them base64-encoded."
run_cmd "kubectl get secrets -n $NAMESPACE"
run_cmd "kubectl get secret node-app-secret -n $NAMESPACE -o yaml"
run_cmd "kubectl get secret node-app-secret -n $NAMESPACE -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo"

run_section "10. Storage Administration"
echo "Explanation: PVCs provide persistent storage, especially for PostgreSQL."
run_cmd "kubectl get pvc -n $NAMESPACE"
run_cmd "kubectl describe pvc -n $NAMESPACE"

run_section "11. Resource Monitoring"
echo "Explanation: These commands show CPU and memory usage."
run_cmd "kubectl top nodes"
run_cmd "kubectl top pods -n $NAMESPACE"

run_section "12. Autoscaling Administration"
echo "Explanation: HPA automatically scales pods based on CPU or memory."
run_cmd "kubectl get hpa -n $NAMESPACE"
run_cmd "kubectl describe hpa node-app-hpa -n $NAMESPACE"

run_section "13. Rollout Administration"
echo "Explanation: Rollouts are used for restart, deployment status, and rollback."
run_cmd "kubectl rollout history deployment/$APP_DEPLOYMENT -n $NAMESPACE"
run_cmd "kubectl rollout status deployment/$APP_DEPLOYMENT -n $NAMESPACE"
echo ""
echo "Useful manual commands:"
echo "kubectl rollout restart deployment/$APP_DEPLOYMENT -n $NAMESPACE"
echo "kubectl rollout undo deployment/$APP_DEPLOYMENT -n $NAMESPACE"

run_section "14. Events Administration"
echo "Explanation: Events are one of the best troubleshooting sources."
run_cmd "kubectl get events -n $NAMESPACE --sort-by=.metadata.creationTimestamp | tail -60"

run_section "15. Kustomize Administration"
echo "Explanation: Kustomize renders all Kubernetes manifests together."
run_cmd "kubectl kustomize $HOME/node-app/k8s/base"
run_cmd "kubectl apply --dry-run=client -k $HOME/node-app/k8s/base"

run_section "16. Application URL Test"
echo "Explanation: Port-forward allows local testing without exposing the service permanently."
PORT=18085
pkill -f "kubectl port-forward svc/nginx $PORT:80" >/dev/null 2>&1 || true
kubectl port-forward svc/nginx $PORT:80 -n $NAMESPACE >/tmp/k8s-admin-port-forward.log 2>&1 &
PF_PID=$!
sleep 5

echo ""
echo "Testing:"
echo "curl http://localhost:$PORT/health"
curl --max-time 5 -s "http://localhost:$PORT/health" || true
echo ""

echo "curl http://localhost:$PORT/api/db-health"
curl --max-time 5 -s "http://localhost:$PORT/api/db-health" || true
echo ""

echo "curl http://localhost:$PORT/api/redis-health"
curl --max-time 5 -s "http://localhost:$PORT/api/redis-health" || true
echo ""

echo "curl http://localhost:$PORT/metrics | grep security_"
curl --max-time 5 -s "http://localhost:$PORT/metrics" | grep security_ || true
echo ""

kill "$PF_PID" >/dev/null 2>&1 || true

run_section "17. Troubleshooting Cheat Sheet"
echo "If pod is CrashLoopBackOff:"
echo "kubectl describe pod POD_NAME -n $NAMESPACE"
echo "kubectl logs POD_NAME -n $NAMESPACE"
echo ""
echo "If service is not working:"
echo "kubectl describe svc SERVICE_NAME -n $NAMESPACE"
echo "kubectl get endpoints SERVICE_NAME -n $NAMESPACE"
echo ""
echo "If HPA shows unknown:"
echo "kubectl top pods -n $NAMESPACE"
echo "kubectl describe hpa node-app-hpa -n $NAMESPACE"
echo ""
echo "If DB health fails:"
echo "kubectl exec -n $NAMESPACE deployment/node-app -- printenv | grep POSTGRES"
echo "kubectl logs -n $NAMESPACE deployment/postgres --tail=80"
echo ""
echo "If Redis health fails:"
echo "kubectl exec -n $NAMESPACE deployment/node-app -- printenv | grep REDIS"
echo "kubectl logs -n $NAMESPACE deployment/redis --tail=80"
echo ""
echo "If image is old:"
echo "docker build --no-cache -t ghcr.io/jcsa2030/elhalawany-devops-lab:security ."
echo "docker push ghcr.io/jcsa2030/elhalawany-devops-lab:security"
echo "kubectl rollout restart deployment/node-app -n $NAMESPACE"

run_section "18. Final Understanding"
echo "Your Kubernetes flow:"
echo "User -> Nginx Service -> Node.js Service -> PostgreSQL + Redis"
echo ""
echo "Your admin flow:"
echo "get -> describe -> logs -> exec -> events -> rollout -> validate"

} | tee "$REPORT_FILE"

echo ""
echo "Report saved to:"
echo "$REPORT_FILE"

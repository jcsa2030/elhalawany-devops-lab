# Kubernetes Base Manifests

## Namespace
devsecops-dev

## Components
- Redis
- PostgreSQL
- Node.js App
- Nginx Reverse Proxy
- HPA
- Ingress

## Access
Local host entry:

127.0.0.1 devsecops.local

## Test Commands

```bash
kubectl apply -k k8s/base
kubectl get all -n devsecops-dev
kubectl get hpa -n devsecops-dev
kubectl get ingress -n devsecops-dev

curl http://devsecops.local/health
curl http://devsecops.local/api/db-health
curl http://devsecops.local/api/redis-health
curl http://devsecops.local/metrics | grep security_

docker stop prometheus 2>/dev/null || true
docker stop grafana 2>/dev/null || true
docker stop cadvisor 2>/dev/null || true
docker stop node-exporter 2>/dev/null || true

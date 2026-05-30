docker start prometheus 2>/dev/null || true
docker start grafana 2>/dev/null || true
docker start cadvisor 2>/dev/null || true
docker start node-exporter 2>/dev/null || true

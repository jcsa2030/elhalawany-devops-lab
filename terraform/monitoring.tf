locals {
  monitoring_stack = {
    prometheus = {
      name = "prometheus"
      port = local.allowed_ports.prometheus
      role = "Metrics Collection"
    }

    grafana = {
      name = "grafana"
      port = local.allowed_ports.grafana
      role = "Dashboards and Visualization"
    }

    node_app_metrics = {
      name     = "node-app-metrics"
      endpoint = "/metrics"
      role     = "Application Metrics"
    }
  }
}

resource "local_file" "monitoring_design" {
  filename = "${path.module}/monitoring-design-${var.environment}.txt"

  content = <<EOT
Monitoring Design - ${var.environment}

Prometheus:
- Name : ${local.monitoring_stack.prometheus.name}
- Port : ${local.monitoring_stack.prometheus.port}
- Role : ${local.monitoring_stack.prometheus.role}

Grafana:
- Name : ${local.monitoring_stack.grafana.name}
- Port : ${local.monitoring_stack.grafana.port}
- Role : ${local.monitoring_stack.grafana.role}

Node.js Application Metrics:
- Name     : ${local.monitoring_stack.node_app_metrics.name}
- Endpoint : ${local.monitoring_stack.node_app_metrics.endpoint}
- Role     : ${local.monitoring_stack.node_app_metrics.role}

Current Verified Metrics:
- /metrics endpoint is working
- security_ metrics confirmed
- Prometheus integration path ready

Future Observability:
- Loki for logs
- Tempo for traces
- OpenTelemetry for distributed telemetry
- SLO / SLA Dashboards
- Alerting Rules
EOT
}

locals {
  compute_nodes = {
    app_server = {
      name   = "node-app-server"
      role   = "Application Runtime"
      subnet = local.subnets.app
      port   = local.allowed_ports.node_app
    }

    cicd_server = {
      name   = "jenkins-server"
      role   = "CI/CD Automation"
      subnet = local.subnets.security
      port   = local.allowed_ports.jenkins
    }

    quality_server = {
      name   = "sonarqube-server"
      role   = "Code Quality and SAST"
      subnet = local.subnets.security
      port   = local.allowed_ports.sonarqube
    }

    monitoring_server = {
      name   = "monitoring-server"
      role   = "Prometheus and Grafana"
      subnet = local.subnets.monitoring
      port   = local.allowed_ports.prometheus
    }
  }
}

resource "local_file" "compute_design" {
  filename = "${path.module}/compute-design-${var.environment}.txt"

  content = <<EOT
Compute Design - ${var.environment}

Application Server:
- Name   : ${local.compute_nodes.app_server.name}
- Role   : ${local.compute_nodes.app_server.role}
- Subnet : ${local.compute_nodes.app_server.subnet}
- Port   : ${local.compute_nodes.app_server.port}

CI/CD Server:
- Name   : ${local.compute_nodes.cicd_server.name}
- Role   : ${local.compute_nodes.cicd_server.role}
- Subnet : ${local.compute_nodes.cicd_server.subnet}
- Port   : ${local.compute_nodes.cicd_server.port}

Quality Server:
- Name   : ${local.compute_nodes.quality_server.name}
- Role   : ${local.compute_nodes.quality_server.role}
- Subnet : ${local.compute_nodes.quality_server.subnet}
- Port   : ${local.compute_nodes.quality_server.port}

Monitoring Server:
- Name   : ${local.compute_nodes.monitoring_server.name}
- Role   : ${local.compute_nodes.monitoring_server.role}
- Subnet : ${local.compute_nodes.monitoring_server.subnet}
- Port   : ${local.compute_nodes.monitoring_server.port}

Future Expansion:
- Kubernetes Control Plane
- Kubernetes Worker Nodes
- ArgoCD
- Vault
- OPA
- Loki
- Tempo
- OpenTelemetry
- Backstage
EOT
}

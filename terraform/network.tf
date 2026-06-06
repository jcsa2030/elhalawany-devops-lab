locals {
  network_name = "${var.project_name}-${var.environment}-network"

  subnets = {
    app        = "10.10.1.0/24"
    monitoring = "10.10.2.0/24"
    security   = "10.10.3.0/24"
  }
}

resource "local_file" "network_design" {
  filename = "${path.module}/network-design-${var.environment}.txt"

  content = <<EOT
Network Name: ${local.network_name}

Subnets:
- App Subnet        : ${local.subnets.app}
- Monitoring Subnet : ${local.subnets.monitoring}
- Security Subnet   : ${local.subnets.security}

Purpose:
This network layer will support:
- Node.js Application
- Jenkins
- SonarQube
- Dependency-Track
- Trivy
- Prometheus
- Grafana
- Future Kubernetes Cluster
EOT
}

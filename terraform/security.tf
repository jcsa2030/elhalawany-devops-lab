locals {
  allowed_ports = {
    ssh              = 22
    node_app         = 8080
    jenkins          = 8081
    sonarqube        = 9000
    dependency_track = 8082
    prometheus       = 9090
    grafana          = 3000
  }
}

resource "local_file" "security_design" {
  filename = "${path.module}/security-design-${var.environment}.txt"

  content = <<EOT
Security Access Design - ${var.environment}

Allowed Ports:
- SSH              : ${local.allowed_ports.ssh}
- Node.js App      : ${local.allowed_ports.node_app}
- Jenkins          : ${local.allowed_ports.jenkins}
- SonarQube        : ${local.allowed_ports.sonarqube}
- Dependency-Track : ${local.allowed_ports.dependency_track}
- Prometheus       : ${local.allowed_ports.prometheus}
- Grafana          : ${local.allowed_ports.grafana}

Security Principles:
- Least Privilege
- Dedicated Monitoring Access
- CI/CD Controlled Deployment
- Future Vault Integration
- Future OPA Policy Enforcement
EOT
}

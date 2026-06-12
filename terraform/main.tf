resource "random_id" "lab_id" {
  byte_length = 4
}

resource "local_file" "devops_lab_inventory" {
  filename = "${path.module}/devops-lab-inventory.txt"

  content = <<EOT
Project     : ${var.project_name}
Environment : ${var.environment}
Owner       : ${var.owner}
Lab ID      : ${random_id.lab_id.hex}

Current Stack:
- Node.js Express App
- Docker
- Jenkins
- SonarQube
- GitLeaks
- Syft SBOM
- Dependency-Track
- Trivy
- Prometheus Metrics
- Grafana / Monitoring Path

Phase:
- Phase 1: Terraform Infrastructure as Code Foundation
EOT
}

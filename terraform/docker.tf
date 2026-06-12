locals {
  docker_platform_containers = {
    app        = "elhalawany-app"
    nginx      = "elhalawany-nginx"
    postgres   = "elhalawany-postgres"
    redis      = "elhalawany-redis"
    vault      = "vault"
    prometheus = "prometheus"
    grafana    = "grafana"
    sonarqube  = "sonarqube"
  }
}

resource "local_file" "docker_platform_inventory" {
  filename = "${path.module}/docker-platform-inventory-${var.environment}.txt"

  content = <<EOT
Docker Platform Inventory - ${var.environment}

Current Running Containers:
- Application : ${local.docker_platform_containers.app}
- Nginx       : ${local.docker_platform_containers.nginx}
- PostgreSQL  : ${local.docker_platform_containers.postgres}
- Redis       : ${local.docker_platform_containers.redis}
- Vault       : ${local.docker_platform_containers.vault}
- Prometheus  : ${local.docker_platform_containers.prometheus}
- Grafana     : ${local.docker_platform_containers.grafana}
- SonarQube   : ${local.docker_platform_containers.sonarqube}

Terraform Objective:
- Prepare Docker provider
- Document current Docker infrastructure
- Prepare controlled migration from docker-compose to Terraform-managed infrastructure
- Prepare future migration to Kubernetes
EOT
}

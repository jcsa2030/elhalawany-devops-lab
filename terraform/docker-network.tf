resource "docker_network" "devsecops_platform_network" {
  name = "${var.project_name}-${var.environment}-tf-network"

  labels {
    label = "project"
    value = var.project_name
  }

  labels {
    label = "environment"
    value = var.environment
  }

  labels {
    label = "managed_by"
    value = "terraform"
  }
}

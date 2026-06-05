resource "docker_image" "busybox" {
  name = "busybox:latest"
}

resource "docker_container" "terraform_test_container" {
  name  = "${var.project_name}-${var.environment}-test-container"
  image = docker_image.busybox.image_id

  command = ["sh", "-c", "while true; do echo Terraform Docker test container is running; sleep 60; done"]

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.devsecops_platform_network.name
  }

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

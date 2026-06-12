resource "docker_image" "node_app_tf" {
  name = "ghcr.io/jcsa2030/elhalawany-devops-lab:security"
}

resource "docker_container" "node_app_tf_service" {
  name  = "${var.project_name}-${var.environment}-app-tf"
  image = docker_image.node_app_tf.image_id

  restart = "unless-stopped"

  env = [
    "NODE_ENV=${var.environment}",
    "PORT=3000",
    "REDIS_HOST=${docker_container.redis_tf_service.name}",
    "REDIS_PORT=6379",
    "POSTGRES_HOST=${docker_container.postgres_tf_service.name}",
    "POSTGRES_PORT=5432",
    "POSTGRES_DB=devsecopsdb",
    "POSTGRES_USER=devsecops",
    "POSTGRES_PASSWORD=devsecops_password_change_me"
  ]

  ports {
    internal = 3000
    external = 8090
  }

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

resource "docker_image" "redis_tf" {
  name = "redis:7-alpine"
}

resource "docker_container" "redis_tf_service" {
  name  = "${var.project_name}-${var.environment}-redis-tf"
  image = docker_image.redis_tf.image_id

  restart = "unless-stopped"

  ports {
    internal = 6379
    external = 6380
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

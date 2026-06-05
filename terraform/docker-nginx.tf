resource "docker_image" "nginx_tf" {
  name = "nginx:alpine"
}

resource "docker_container" "nginx_tf_service" {
  name  = "${var.project_name}-${var.environment}-nginx-tf"
  image = docker_image.nginx_tf.image_id

  restart = "unless-stopped"

  ports {
    internal = 80
    external = 8089
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

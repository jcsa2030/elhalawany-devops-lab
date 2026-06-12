resource "docker_image" "postgres_tf" {
  name = "postgres:16-alpine"
}

resource "docker_volume" "postgres_tf_data" {
  name = "${var.project_name}-${var.environment}-postgres-tf-data"
}

resource "docker_container" "postgres_tf_service" {
  name  = "${var.project_name}-${var.environment}-postgres-tf"
  image = docker_image.postgres_tf.image_id

  restart = "unless-stopped"

  env = [
    "POSTGRES_DB=devsecopsdb",
    "POSTGRES_USER=devsecops",
    "POSTGRES_PASSWORD=devsecops_password_change_me"
  ]

  ports {
    internal = 5432
    external = 5433
  }

  volumes {
    volume_name    = docker_volume.postgres_tf_data.name
    container_path = "/var/lib/postgresql/data"
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

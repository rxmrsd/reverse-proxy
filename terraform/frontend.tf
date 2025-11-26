# Cloud Run service for Frontend (Configuration ②: Reverse proxy)
resource "google_cloud_run_v2_service" "frontend" {
  name     = var.frontend_service_name
  location = var.region

  template {
    containers {
      image = local.frontend_image_url

      ports {
        container_port = 80
      }

      env {
        name  = "BACKEND_URL"
        value = google_cloud_run_v2_service.backend.uri
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    vpc_access {
      network_interfaces {
        network    = "proxy-subnet"
        subnetwork = "proxy-subnet3"
      }
      egress = "ALL_TRAFFIC"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Allow all traffic to frontend (public access)
  ingress = "INGRESS_TRAFFIC_ALL"

  depends_on = [google_cloud_run_v2_service.backend]
}

# Cloud Run service for Frontend Static (Configuration ①: Static file serving only)
resource "google_cloud_run_v2_service" "frontend_static" {
  name     = var.frontend_static_service_name
  location = var.region

  template {
    containers {
      image = local.frontend_static_image_url

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    vpc_access {
      network_interfaces {
        network    = "proxy-subnet"
        subnetwork = "proxy-subnet3"
      }
      egress = "ALL_TRAFFIC"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Allow all traffic to frontend (public access)
  ingress = "INGRESS_TRAFFIC_ALL"

  depends_on = [google_cloud_run_v2_service.backend]
}

# Allow unauthenticated access to frontend (reverse proxy)
resource "google_cloud_run_v2_service_iam_member" "frontend_noauth" {
  location = google_cloud_run_v2_service.frontend.location
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow unauthenticated access to frontend-static
resource "google_cloud_run_v2_service_iam_member" "frontend_static_noauth" {
  location = google_cloud_run_v2_service.frontend_static.location
  name     = google_cloud_run_v2_service.frontend_static.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "frontend_url" {
  description = "URL of the frontend Cloud Run service (reverse proxy)"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "frontend_static_url" {
  description = "URL of the frontend static Cloud Run service"
  value       = google_cloud_run_v2_service.frontend_static.uri
}

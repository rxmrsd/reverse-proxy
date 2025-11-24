# Cloud Run service for Frontend (Flutter Web + Nginx)
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
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Allow all traffic to frontend (public access)
  ingress = "INGRESS_TRAFFIC_ALL"

  depends_on = [google_cloud_run_v2_service.backend]
}

# Note: Authentication is handled by gcloud run deploy --allow-unauthenticated in Cloud Build
# IAM settings are not managed by Terraform to avoid permission issues

output "frontend_url" {
  description = "URL of the frontend Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.uri
}

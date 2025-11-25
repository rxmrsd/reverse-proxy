# Cloud Run service for Backend (FastAPI)
resource "google_cloud_run_v2_service" "backend" {
  name     = var.backend_service_name
  location = var.region

  template {
    containers {
      image = local.backend_image_url

      ports {
        container_port = 8000
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

  # Internal traffic only - backend is only accessible from frontend
  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"
}

# Allow unauthenticated access to backend
# Even though it's internal only, it needs this permission for frontend to access
resource "google_cloud_run_v2_service_iam_member" "backend_noauth" {
  location = google_cloud_run_v2_service.backend.location
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "backend_url" {
  description = "URL of the backend Cloud Run service"
  value       = google_cloud_run_v2_service.backend.uri
}

################################################################################
# Frontend Cloud Run Service Module
#
# This module deploys the SAME Flutter application with different deployment
# strategies for handling backend API communication.
#
# Two deployment strategies are supported:
# 1. "direct-backend-access" - Browser makes direct API calls to backend
# 2. "reverse-proxy" - Nginx proxies API calls to backend (same-origin)
################################################################################

resource "google_cloud_run_v2_service" "frontend" {
  name     = var.service_name
  location = var.region

  template {
    containers {
      image = var.image_url

      ports {
        container_port = var.container_port
      }

      # Conditionally add BACKEND_URL for reverse proxy strategy
      dynamic "env" {
        for_each = var.deployment_strategy == "reverse-proxy" ? [1] : []
        content {
          name  = "BACKEND_URL"
          value = var.backend_url
        }
      }

      resources {
        limits = {
          cpu    = var.resources.cpu
          memory = var.resources.memory
        }
      }
    }

    scaling {
      min_instance_count = var.scaling.min_instance_count
      max_instance_count = var.scaling.max_instance_count
    }

    vpc_access {
      network_interfaces {
        network    = var.vpc.network
        subnetwork = var.vpc.subnetwork
      }
      egress = "ALL_TRAFFIC"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  ingress = var.ingress
}

# IAM policy for public access
resource "google_cloud_run_v2_service_iam_member" "noauth" {
  location = google_cloud_run_v2_service.frontend.location
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

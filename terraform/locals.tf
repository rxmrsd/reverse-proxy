# Local values for computed configurations
locals {
  # Artifact Registry base URL
  artifact_registry_url = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_name}"

  # Docker image URLs (use provided images or construct from Artifact Registry)
  backend_image_url         = var.backend_image != "" ? var.backend_image : "${local.artifact_registry_url}/reverse-proxy-backend:${var.image_tag}"
  frontend_image_url        = var.frontend_image != "" ? var.frontend_image : "${local.artifact_registry_url}/reverse-proxy-frontend:${var.image_tag}"
  frontend_static_image_url = var.frontend_static_image != "" ? var.frontend_static_image : "${local.artifact_registry_url}/reverse-proxy-frontend-static:${var.image_tag}"

  # ==========================================
  # Frontend Common Configuration
  # ==========================================
  # Both frontend deployments serve the SAME Flutter application
  # but use different deployment strategies for backend communication

  frontend_common_config = {
    resources = {
      cpu    = "1"
      memory = "512Mi"
    }
    scaling = {
      min_instance_count = 0
      max_instance_count = 10
    }
    vpc = {
      network    = module.vpc.network_name
      subnetwork = module.vpc.subnet_name
    }
    ingress = "INGRESS_TRAFFIC_ALL"
  }

  # ==========================================
  # Deployment Strategy Configurations
  # ==========================================

  # Strategy 1: Direct Backend Access (frontend-static)
  # - Browser makes direct API calls to backend
  # - Backend must be publicly accessible
  # - Simple nginx static file server (port 8080)
  # - CORS required on backend
  frontend_static_deployment = {
    strategy       = "direct-backend-access"
    container_port = 8080
    description    = "Static file serving - Browser calls backend directly"
  }

  # Strategy 2: Reverse Proxy (frontend)
  # - API calls to same-origin /api/*
  # - Nginx proxies to internal backend
  # - Backend can be internal-only (more secure)
  # - No CORS issues (same-origin)
  frontend_proxy_deployment = {
    strategy       = "reverse-proxy"
    container_port = 80
    description    = "Reverse proxy - Nginx proxies to backend"
  }
}

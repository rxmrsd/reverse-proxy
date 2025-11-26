################################################################################
# Frontend Deployments
#
# IMPORTANT: Both deployments serve the SAME Flutter application
# The difference is only in the deployment strategy for backend communication
#
# Two deployment strategies:
# 1. Direct Backend Access (frontend-static)
# 2. Reverse Proxy (frontend)
#
# See modules/frontend-proxy/README.md for detailed explanation
################################################################################

################################################################################
# Strategy 1: Direct Backend Access
# Service: frontend-static
# Docker Image: frontend-static (frontend-static/Dockerfile)
################################################################################
# - Browser makes direct API calls to backend
# - Backend must be publicly accessible (INGRESS_TRAFFIC_ALL)
# - Simple nginx static file server (port 8080)
# - CORS must be configured on backend
# - Use case: Development, simple deployments
################################################################################

module "frontend_static" {
  source = "./modules/frontend"

  service_name        = var.frontend_static_service_name
  region              = var.region
  image_url           = local.frontend_static_image_url
  deployment_strategy = local.frontend_static_deployment.strategy
  container_port      = local.frontend_static_deployment.container_port

  resources = local.frontend_common_config.resources
  scaling   = local.frontend_common_config.scaling
  vpc       = local.frontend_common_config.vpc
  ingress   = local.frontend_common_config.ingress

  depends_on = [google_cloud_run_v2_service.backend]
}

################################################################################
# Strategy 2: Reverse Proxy
# Service: frontend
# Docker Image: frontend (frontend-proxy/Dockerfile)
################################################################################
# - Flutter app makes API calls to same-origin /api/*
# - Nginx (in Cloud Run) proxies /api/* to internal backend
# - Backend can be INGRESS_TRAFFIC_INTERNAL_ONLY (more secure)
# - Nginx handles routing (port 80)
# - No CORS issues (same-origin requests)
# - Use case: Production, enhanced security
################################################################################

module "frontend_proxy" {
  source = "./modules/frontend"

  service_name        = var.frontend_service_name
  region              = var.region
  image_url           = local.frontend_image_url
  deployment_strategy = local.frontend_proxy_deployment.strategy
  container_port      = local.frontend_proxy_deployment.container_port
  backend_url         = google_cloud_run_v2_service.backend.uri

  resources = local.frontend_common_config.resources
  scaling   = local.frontend_common_config.scaling
  vpc       = local.frontend_common_config.vpc
  ingress   = local.frontend_common_config.ingress

  depends_on = [google_cloud_run_v2_service.backend]
}

################################################################################
# Outputs
################################################################################

output "frontend_url" {
  description = "URL of the frontend Cloud Run service (Strategy 2: Reverse Proxy)"
  value       = module.frontend_proxy.service_url
}

output "frontend_static_url" {
  description = "URL of the frontend static Cloud Run service (Strategy 1: Direct Backend Access)"
  value       = module.frontend_static.service_url
}

output "deployment_strategies" {
  description = "Deployment strategies used for each frontend"
  value = {
    frontend_static = {
      url         = module.frontend_static.service_url
      strategy    = module.frontend_static.deployment_strategy
      description = local.frontend_static_deployment.description
    }
    frontend_proxy = {
      url         = module.frontend_proxy.service_url
      strategy    = module.frontend_proxy.deployment_strategy
      description = local.frontend_proxy_deployment.description
    }
  }
}

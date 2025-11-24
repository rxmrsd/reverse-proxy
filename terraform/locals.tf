# Local values for computed configurations
locals {
  # Artifact Registry base URL
  artifact_registry_url = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_name}"

  # Docker image URLs (use provided images or construct from Artifact Registry)
  backend_image_url = var.backend_image != "" ? var.backend_image : "${local.artifact_registry_url}/reverse-proxy-backend:${var.image_tag}"

  frontend_image_url = var.frontend_image != "" ? var.frontend_image : "${local.artifact_registry_url}/reverse-proxy-frontend:${var.image_tag}"
}

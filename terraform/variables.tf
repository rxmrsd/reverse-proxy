variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run services"
  type        = string
  default     = "asia-northeast1"
}

variable "repository_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "reverse-proxy"
}

variable "backend_service_name" {
  description = "Cloud Run service name for backend"
  type        = string
  default     = "reverse-proxy-backend"
}

variable "frontend_service_name" {
  description = "Cloud Run service name for frontend (Strategy 2: Reverse Proxy) - Same Flutter app, different deployment strategy"
  type        = string
  default     = "reverse-proxy-frontend"
}

variable "frontend_static_service_name" {
  description = "Cloud Run service name for frontend static (Strategy 1: Direct Backend Access) - Same Flutter app, different deployment strategy"
  type        = string
  default     = "reverse-proxy-frontend-static"
}

variable "backend_image" {
  description = "Docker image for backend (will be built by Cloud Build)"
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Docker image for frontend reverse proxy (Strategy 2) - Built from frontend-proxy/Dockerfile with nginx reverse proxy config"
  type        = string
  default     = ""
}

variable "frontend_static_image" {
  description = "Docker image for frontend static (Strategy 1) - Built from frontend-static/Dockerfile with basic nginx"
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

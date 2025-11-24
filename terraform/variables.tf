variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run services"
  type        = string
  default     = "asia-northeast1"
}

variable "backend_service_name" {
  description = "Cloud Run service name for backend"
  type        = string
  default     = "reverse-proxy-backend"
}

variable "frontend_service_name" {
  description = "Cloud Run service name for frontend"
  type        = string
  default     = "reverse-proxy-frontend"
}

variable "backend_image" {
  description = "Docker image for backend (will be built by Cloud Build)"
  type        = string
}

variable "frontend_image" {
  description = "Docker image for frontend (will be built by Cloud Build)"
  type        = string
}

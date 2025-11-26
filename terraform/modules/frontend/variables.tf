variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "image_url" {
  description = "Docker image URL"
  type        = string
}

variable "deployment_strategy" {
  description = "Deployment strategy: 'direct-backend-access' or 'reverse-proxy'"
  type        = string
  validation {
    condition     = contains(["direct-backend-access", "reverse-proxy"], var.deployment_strategy)
    error_message = "deployment_strategy must be either 'direct-backend-access' or 'reverse-proxy'"
  }
}

variable "container_port" {
  description = "Container port (8080 for static, 80 for proxy)"
  type        = number
}

variable "backend_url" {
  description = "Backend URL (required for reverse-proxy strategy)"
  type        = string
  default     = ""
}

variable "resources" {
  description = "Container resource limits"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "scaling" {
  description = "Auto-scaling configuration"
  type = object({
    min_instance_count = number
    max_instance_count = number
  })
}

variable "vpc" {
  description = "VPC configuration"
  type = object({
    network    = string
    subnetwork = string
  })
}

variable "ingress" {
  description = "Ingress traffic configuration"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "depends_on_services" {
  description = "List of services this deployment depends on"
  type        = list(any)
  default     = []
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.name
}

output "deployment_strategy" {
  description = "Deployment strategy used"
  value       = var.deployment_strategy
}

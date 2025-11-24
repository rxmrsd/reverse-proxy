# Use existing Artifact Registry repository (created by setup.sh)
# This prevents conflicts when the repository already exists
data "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.repository_name
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.docker_repo.repository_id}"
}

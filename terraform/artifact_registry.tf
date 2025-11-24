# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.repository_name
  description   = "Docker repository for reverse proxy application"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }

  lifecycle {
    # Prevent destruction if repository already exists
    # Use: terraform import google_artifact_registry_repository.docker_repo projects/PROJECT_ID/locations/REGION/repositories/REPO_NAME
    ignore_changes = [
      cleanup_policies,
    ]
  }
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

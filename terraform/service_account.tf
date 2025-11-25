# Service account for Cloud Build to deploy Cloud Run services
resource "google_service_account" "cloud_build_deploy" {
  account_id   = "reverse-proxy-deploy"
  display_name = "Reverse Proxy Deploy Service Account"
  description  = "Service account used by Cloud Build to deploy reverse-proxy Cloud Run services and manage IAM policies"
}

# Grant necessary roles to the service account
resource "google_project_iam_member" "cloud_build_deploy_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_deploy.email}"
}

resource "google_project_iam_member" "cloud_build_deploy_iam_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_build_deploy.email}"
}

resource "google_project_iam_member" "cloud_build_deploy_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_build_deploy.email}"
}

# Allow the default Cloud Build service account to use this service account
resource "google_service_account_iam_member" "cloud_build_sa_user" {
  service_account_id = google_service_account.cloud_build_deploy.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.project_id}@cloudbuild.gserviceaccount.com"
}

output "cloud_build_deploy_sa_email" {
  description = "Email of the Cloud Build deploy service account"
  value       = google_service_account.cloud_build_deploy.email
}

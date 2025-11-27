# Service account for Cloud Build deployments
#
# NOTE: The service account and IAM permissions are now managed via gcloud
# in the setup-service-account.sh script instead of Terraform.
# This is because Terraform requires resourcemanager.projects.setIamPolicy
# permission which may not be available to all users.
#
# The service account is created and managed by running:
#   ./deployment/setup-service-account.sh
#
# Service account name: reverse-proxy-deploy@PROJECT_ID.iam.gserviceaccount.com
#
# Granted roles:
# - roles/run.admin
# - roles/iam.serviceAccountUser
# - roles/artifactregistry.reader
# - roles/storage.admin
# - roles/cloudbuild.builds.builder
# - roles/logging.logWriter
# - roles/resourcemanager.projectIamAdmin
# - roles/compute.networkAdmin

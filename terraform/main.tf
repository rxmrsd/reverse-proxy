terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Store Terraform state in GCS bucket
  # This ensures state persists across Cloud Build runs
  backend "gcs" {
    # The bucket name will be set via -backend-config in Cloud Build
    # Format: gs://${PROJECT_ID}-terraform-state/terraform.tfstate
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

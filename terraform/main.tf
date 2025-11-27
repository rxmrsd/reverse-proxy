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

# VPC Network Configuration
module "vpc" {
  source = "./modules/vpc"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name
  subnet_cidr  = var.subnet_cidr
}

# VPC Outputs
output "vpc_network_id" {
  description = "The ID of the VPC network"
  value       = module.vpc.network_id
}

output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "vpc_subnet_name" {
  description = "The name of the subnet"
  value       = module.vpc.subnet_name
}

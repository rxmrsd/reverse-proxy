#!/bin/bash

# Destroy all Cloud Run resources using Terraform
# This script removes all deployed resources from Google Cloud

set -e

# Load environment variables from .env file
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found"
  echo "Please copy .env.example to .env and configure your settings"
  exit 1
fi

# Validate required environment variables
if [ -z "$GCP_PROJECT_ID" ]; then
  echo "Error: GCP_PROJECT_ID is not set in .env"
  exit 1
fi

if [ -z "$GCP_REGION" ]; then
  echo "Error: GCP_REGION is not set in .env"
  exit 1
fi

if [ -z "$ARTIFACT_REGISTRY_REPOSITORY" ]; then
  echo "Error: ARTIFACT_REGISTRY_REPOSITORY is not set in .env"
  exit 1
fi

# Set default values
IMAGE_TAG="${IMAGE_TAG:-latest}"
BACKEND_SERVICE_NAME="${BACKEND_SERVICE_NAME:-reverse-proxy-backend}"
FRONTEND_SERVICE_NAME="${FRONTEND_SERVICE_NAME:-reverse-proxy-frontend}"

echo "================================================"
echo "WARNING: Destroying Cloud Run Resources"
echo "================================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "Repository: $ARTIFACT_REGISTRY_REPOSITORY"
echo "================================================"
echo ""
echo "This will destroy:"
echo "  - Cloud Run service: $BACKEND_SERVICE_NAME"
echo "  - Cloud Run service: $FRONTEND_SERVICE_NAME"
echo "  - Artifact Registry repository: $ARTIFACT_REGISTRY_REPOSITORY"
echo ""
read -p "Are you sure you want to continue? (yes/no): " DESTROY_CONFIRM

if [ "$DESTROY_CONFIRM" != "yes" ]; then
  echo "Destruction cancelled"
  exit 0
fi

# Navigate to terraform directory
cd terraform

# Initialize Terraform (if not already initialized)
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Destroy resources
echo ""
echo "Destroying resources..."
terraform destroy \
  -var="project_id=$GCP_PROJECT_ID" \
  -var="region=$GCP_REGION" \
  -var="repository_name=$ARTIFACT_REGISTRY_REPOSITORY" \
  -var="image_tag=$IMAGE_TAG" \
  -var="backend_service_name=$BACKEND_SERVICE_NAME" \
  -var="frontend_service_name=$FRONTEND_SERVICE_NAME" \
  -auto-approve

cd ..

echo ""
echo "================================================"
echo "Resources destroyed successfully!"
echo "================================================"

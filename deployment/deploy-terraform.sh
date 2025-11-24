#!/bin/bash

# Deploy script using Terraform only
# This script assumes Docker images are already built and pushed to Artifact Registry

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
echo "Deploying to Cloud Run with Terraform"
echo "================================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "Repository: $ARTIFACT_REGISTRY_REPOSITORY"
echo "Image Tag: $IMAGE_TAG"
echo "================================================"
echo ""

# Navigate to terraform directory
cd terraform

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan deployment
echo ""
echo "Planning deployment..."
terraform plan \
  -var="project_id=$GCP_PROJECT_ID" \
  -var="region=$GCP_REGION" \
  -var="repository_name=$ARTIFACT_REGISTRY_REPOSITORY" \
  -var="image_tag=$IMAGE_TAG" \
  -var="backend_service_name=$BACKEND_SERVICE_NAME" \
  -var="frontend_service_name=$FRONTEND_SERVICE_NAME" \
  -out=tfplan

# Apply deployment
echo ""
read -p "Do you want to apply this plan? (yes/no): " APPLY_CONFIRM
if [ "$APPLY_CONFIRM" = "yes" ]; then
  echo "Applying deployment..."
  terraform apply tfplan

  echo ""
  echo "================================================"
  echo "Deployment completed!"
  echo "================================================"
  echo ""
  echo "Backend URL:"
  terraform output -raw backend_url
  echo ""
  echo "Frontend URL:"
  terraform output -raw frontend_url
  echo ""
  echo "================================================"
else
  echo "Deployment cancelled"
  rm -f tfplan
fi

cd ..

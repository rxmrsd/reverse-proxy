#!/bin/bash

# Setup script for Google Cloud project
# This script enables required APIs and creates Artifact Registry

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

echo "================================================"
echo "Google Cloud Project Setup"
echo "================================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "Repository: $ARTIFACT_REGISTRY_REPOSITORY"
echo "================================================"
echo ""

# Set the active project
echo "Setting active project..."
gcloud config set project "$GCP_PROJECT_ID"

# Enable required APIs
echo ""
echo "Enabling required APIs..."
gcloud services enable run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com

# Create Artifact Registry repository
echo ""
echo "Creating Artifact Registry repository..."
if gcloud artifacts repositories describe "$ARTIFACT_REGISTRY_REPOSITORY" \
  --location="$GCP_REGION" &>/dev/null; then
  echo "Artifact Registry repository '$ARTIFACT_REGISTRY_REPOSITORY' already exists"
else
  gcloud artifacts repositories create "$ARTIFACT_REGISTRY_REPOSITORY" \
    --repository-format=docker \
    --location="$GCP_REGION" \
    --description="Docker repository for reverse proxy application"
  echo "Artifact Registry repository created successfully"
fi

echo ""
echo "================================================"
echo "Setup completed successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Run './deployment/deploy-cloudbuild.sh' to deploy with Cloud Build + Terraform"
echo "  2. Or run './deployment/deploy-terraform.sh' to deploy with Terraform only"
echo "================================================"

#!/bin/bash

# Deploy script using Cloud Build + Terraform
# This script builds Docker images and deploys them to Cloud Run using Terraform

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
echo "Deploying to Cloud Run with Cloud Build + Terraform"
echo "================================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "Repository: $ARTIFACT_REGISTRY_REPOSITORY"
echo "================================================"
echo ""

# Set the active project
gcloud config set project "$GCP_PROJECT_ID"

# Submit build to Cloud Build
echo "Submitting build to Cloud Build..."
gcloud builds submit \
  --config=cloudbuild-deploy.yaml \
  --substitutions=_REGION="$GCP_REGION",_REPOSITORY="$ARTIFACT_REGISTRY_REPOSITORY"

echo ""
echo "================================================"
echo "Deployment completed!"
echo "================================================"
echo ""
echo "To view your services:"
echo "  Backend:  gcloud run services describe $BACKEND_SERVICE_NAME --region=$GCP_REGION --format='value(status.url)'"
echo "  Frontend: gcloud run services describe $FRONTEND_SERVICE_NAME --region=$GCP_REGION --format='value(status.url)'"
echo "================================================"

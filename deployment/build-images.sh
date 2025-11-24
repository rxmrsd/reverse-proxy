#!/bin/bash

# Build and push Docker images to Artifact Registry
# This script builds both backend and frontend images locally and pushes them

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

# Construct image URLs
REGISTRY_URL="$GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/$ARTIFACT_REGISTRY_REPOSITORY"
BACKEND_IMAGE="$REGISTRY_URL/reverse-proxy-backend:$IMAGE_TAG"
FRONTEND_IMAGE="$REGISTRY_URL/reverse-proxy-frontend:$IMAGE_TAG"

echo "================================================"
echo "Building and Pushing Docker Images"
echo "================================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "Repository: $ARTIFACT_REGISTRY_REPOSITORY"
echo "Image Tag: $IMAGE_TAG"
echo "================================================"
echo ""

# Configure Docker authentication for Artifact Registry
echo "Configuring Docker authentication..."
gcloud auth configure-docker "$GCP_REGION-docker.pkg.dev" --quiet

# Build and push backend image
echo ""
echo "================================================"
echo "Building backend image..."
echo "================================================"
docker build -t "$BACKEND_IMAGE" ./backend

echo ""
echo "Pushing backend image..."
docker push "$BACKEND_IMAGE"

# Build and push frontend image
echo ""
echo "================================================"
echo "Building frontend image..."
echo "================================================"
docker build -t "$FRONTEND_IMAGE" ./frontend

echo ""
echo "Pushing frontend image..."
docker push "$FRONTEND_IMAGE"

echo ""
echo "================================================"
echo "Images built and pushed successfully!"
echo "================================================"
echo "Backend:  $BACKEND_IMAGE"
echo "Frontend: $FRONTEND_IMAGE"
echo "================================================"
echo ""
echo "Next step: Run './deployment/deploy-terraform.sh' to deploy with Terraform"

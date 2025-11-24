#!/bin/bash

# Deploy backend only
# This script deploys only the backend service

set -e

# Load environment variables
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo "Error: .env file not found"
  echo "Please create .env file from .env.example"
  exit 1
fi

echo "================================================"
echo "Deploying Backend"
echo "================================================"
echo "Project: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "================================================"

# Submit build to Cloud Build
gcloud builds submit \
  --config=.cloudbuild/backend.yaml \
  --region="$GCP_REGION" \
  --substitutions=_REGION="$GCP_REGION",_REPOSITORY="$ARTIFACT_REGISTRY_REPOSITORY" \
  .

echo ""
echo "================================================"
echo "Deployment completed!"
echo "================================================"
echo ""
echo "To view your service:"
echo "  gcloud run services describe reverse-proxy-backend --region=$GCP_REGION --format='value(status.url)'"
echo "================================================"

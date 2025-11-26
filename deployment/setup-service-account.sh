#!/bin/bash

# Setup script for deploying the reverse-proxy-deploy service account
# This must be run before the first Cloud Build deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Service Account Setup for Cloud Build${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}Error: Could not get project ID from gcloud config${NC}"
  echo "Please run: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

REGION="asia-northeast1"

echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

echo -e "${YELLOW}Step 1: Creating service account with gcloud...${NC}"

# Check if service account already exists
if gcloud iam service-accounts describe reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com &>/dev/null; then
  echo "Service account already exists. Skipping creation."
else
  echo "Creating service account..."
  gcloud iam service-accounts create reverse-proxy-deploy \
    --display-name="Reverse Proxy Deploy Service Account" \
    --description="Service account used by Cloud Build to deploy reverse-proxy Cloud Run services and manage IAM policies"
fi

echo ""
echo -e "${YELLOW}Step 2: Granting IAM permissions via gcloud...${NC}"

echo "Adding roles/run.admin..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin" \
  --condition=None

echo "Adding roles/iam.serviceAccountUser..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None

echo "Adding roles/artifactregistry.reader..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader" \
  --condition=None

echo "Adding roles/storage.admin..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin" \
  --condition=None

echo "Adding roles/cloudbuild.builds.builder..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.builder" \
  --condition=None

echo "Adding roles/logging.logWriter..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter" \
  --condition=None

echo "Adding roles/resourcemanager.projectIamAdmin..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin" \
  --condition=None

echo ""
echo -e "${YELLOW}Step 3: Granting GCS bucket permissions...${NC}"
echo "Adding storage.objectAdmin permission to Terraform state bucket..."
gsutil iam ch serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com:objectAdmin \
  gs://${PROJECT_ID}-terraform-state

echo "Setting up Cloud Build staging bucket permissions..."
# Cloud Build may use various bucket patterns for staging
# Grant permissions to common patterns
for bucket_pattern in "${PROJECT_ID}_cloudbuild" "${PROJECT_ID}-cloudbuild" "staging.${PROJECT_ID}.appspot.com"; do
  if gsutil ls gs://${bucket_pattern} &>/dev/null; then
    echo "Adding storage.objectAdmin permission to bucket: ${bucket_pattern}"
    gsutil iam ch serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com:objectAdmin \
      gs://${bucket_pattern}
  fi
done

# Also grant permission at the project level for any future Cloud Build buckets
echo "Note: The service account has roles/storage.admin which should provide access to Cloud Build staging buckets."
echo "If you encounter permission errors, the staging bucket may need explicit permissions."

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Service Account Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Service Account: reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "Next steps:"
echo "1. Run Cloud Build deployment with the deployment script:"
echo "   ./deployment/deploy-cloudbuild.sh"
echo ""
echo "2. Or manually with gcloud:"
echo "   gcloud builds submit --config=.cloudbuild/cloudbuild-deploy.yaml \\"
echo "     --service-account=projects/${PROJECT_ID}/serviceAccounts/reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""

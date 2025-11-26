# Service Account Setup for Cloud Build

This document explains how to set up the dedicated service account for Cloud Build deployments.

## Problem

The default Cloud Build service account (`PROJECT_NUMBER-compute@developer.gserviceaccount.com`) lacks permissions to set IAM policies on Cloud Run services, causing permission errors during deployment.

## Solution

We create a dedicated service account with the necessary permissions and configure Cloud Build to use it.

## Setup Steps

### 1. Set Environment Variables

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="asia-northeast1"
```

### 2. Deploy the Service Account with Terraform

First, we need to deploy just the service account using Terraform:

```bash
cd terraform

# Initialize Terraform (if not already done)
terraform init -backend-config=bucket=${PROJECT_ID}-terraform-state -backend-config=prefix=reverse-proxy

# Deploy only the service account and its IAM bindings
terraform apply \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="repository_name=reverse-proxy" \
  -var="image_tag=latest" \
  -target=google_service_account.cloud_build_deploy \
  -target=google_project_iam_member.cloud_build_deploy_run_admin \
  -target=google_project_iam_member.cloud_build_deploy_iam_admin \
  -target=google_project_iam_member.cloud_build_deploy_artifact_registry \
  -target=google_project_iam_member.cloud_build_deploy_storage_admin

# Grant additional permissions via gcloud
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
```

Or use the deployment script (recommended):

```bash
cd ..
./deployment/setup-service-account.sh
```

### 3. Update Cloud Build Trigger (Optional)

If you're using Cloud Build triggers, you can configure them to use the service account through the GCP Console or gcloud:

```bash
# Example: Update a trigger to use the service account
gcloud builds triggers update TRIGGER_NAME \
  --service-account=projects/${PROJECT_ID}/serviceAccounts/reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com
```

### 4. Run Cloud Build with the Service Account

Use the deployment script (recommended):

```bash
./deployment/deploy-cloudbuild.sh
```

Or run manually with gcloud:

```bash
gcloud builds submit \
  --config=.cloudbuild/cloudbuild-deploy.yaml \
  --region=${REGION} \
  --gcs-source-staging-dir=gs://${PROJECT_ID}-terraform-state/cloudbuild-source \
  --service-account=projects/${PROJECT_ID}/serviceAccounts/reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com \
  --substitutions=_REGION=${REGION},_REPOSITORY=reverse-proxy
```

The deployment script automatically:
- Uses the reverse-proxy-deploy service account
- Stages source code in the Terraform state bucket (which the service account has access to)

## Service Account Permissions

The service account has the following roles:

- **roles/run.admin**: Full control over Cloud Run services
- **roles/iam.serviceAccountUser**: Ability to act as service accounts
- **roles/artifactregistry.reader**: Read access to Artifact Registry
- **roles/storage.admin**: Full control over Cloud Storage (for build sources and artifacts)
- **roles/cloudbuild.builds.builder**: Execute Cloud Build builds
- **roles/logging.logWriter**: Write logs to Cloud Logging
- **roles/resourcemanager.projectIamAdmin**: Manage IAM policies (required for Terraform to set Cloud Run IAM policies)

## IAM Policy Management

With this setup:
- IAM policies for Cloud Run services are now managed by Terraform
- The manual `gcloud run services add-iam-policy-binding` step has been removed from Cloud Build
- All services allow unauthenticated access (`allUsers` as invoker)

## Verification

After setup, verify the service account exists and has the correct permissions:

```bash
# Check service account
gcloud iam service-accounts describe reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com

# Check IAM bindings
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
```

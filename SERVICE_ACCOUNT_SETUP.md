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
  -target=google_service_account_iam_member.cloud_build_sa_user
```

### 3. Grant Cloud Build Permission to Use the Service Account

The Cloud Build service account needs permission to impersonate the new service account:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com \
  --member="serviceAccount:${PROJECT_ID}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

This is already handled by the `google_service_account_iam_member.cloud_build_sa_user` resource in Terraform.

### 4. Update Cloud Build Trigger (Optional)

If you're using Cloud Build triggers, you can configure them to use the service account through the GCP Console or gcloud:

```bash
# Example: Update a trigger to use the service account
gcloud builds triggers update TRIGGER_NAME \
  --service-account=projects/${PROJECT_ID}/serviceAccounts/reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com
```

### 5. Run Cloud Build with the Service Account

When running Cloud Build manually, you can specify the service account:

```bash
gcloud builds submit \
  --config=.cloudbuild/cloudbuild-deploy.yaml \
  --service-account=projects/${PROJECT_ID}/serviceAccounts/reverse-proxy-deploy@${PROJECT_ID}.iam.gserviceaccount.com
```

## Service Account Permissions

The service account has the following roles:

- **roles/run.admin**: Full control over Cloud Run services
- **roles/iam.serviceAccountUser**: Ability to act as service accounts
- **roles/artifactregistry.reader**: Read access to Artifact Registry

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

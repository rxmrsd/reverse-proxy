# Deployment Guide

This guide explains how to deploy the reverse proxy application to Google Cloud Run.

## Prerequisites

1. Google Cloud Project with billing enabled
2. gcloud CLI installed and configured
3. Required APIs enabled:

```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## Deployment Methods

### Method 1: Complete Deployment with Cloud Build + Terraform (Recommended)

This is the simplest method that handles everything: creating Artifact Registry, building images, pushing them, and deploying with Terraform.

```bash
# One command to deploy everything
gcloud builds submit \
  --config=cloudbuild-deploy.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy
```

This will:
1. Create Artifact Registry repository (if using Terraform)
2. Build Docker images for backend and frontend
3. Push images to Artifact Registry
4. Deploy Cloud Run services using Terraform
5. Display the deployment URLs

**Note**: For the first deployment, you need to create the Artifact Registry repository manually:

```bash
gcloud artifacts repositories create reverse-proxy \
  --repository-format=docker \
  --location=asia-northeast1 \
  --description="Docker repository for reverse proxy app"
```

Or use Terraform to create it:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id

terraform init
terraform apply -target=google_artifact_registry_repository.docker_repo
cd ..

# Then run the complete deployment
gcloud builds submit --config=cloudbuild-deploy.yaml
```

### Method 2: Cloud Build Only (Without Terraform)

Deploy services directly using Cloud Build without Terraform.

```bash
# Deploy backend
gcloud builds submit \
  --config=backend/cloudbuild.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy

# Deploy frontend (after backend is deployed)
gcloud builds submit \
  --config=frontend/cloudbuild.yaml \
  --substitutions=_REGION=asia-northeast1,_REPOSITORY=reverse-proxy
```

### Method 3: Terraform Only (Manual Image Build)

Use Terraform to manage infrastructure, building images manually.

1. Create Artifact Registry and build images:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION=asia-northeast1
export REPOSITORY=reverse-proxy

# Build and push backend
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/reverse-proxy-backend:latest ./backend
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/reverse-proxy-backend:latest

# Build and push frontend
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/reverse-proxy-frontend:latest ./frontend
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/reverse-proxy-frontend:latest
```

2. Deploy with Terraform:

```bash
cd terraform

# Copy and edit terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set project_id and optionally image_tag

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var="project_id=${PROJECT_ID}"

# Apply the deployment
terraform apply -var="project_id=${PROJECT_ID}"
```

## Configuration

### Environment Variables

#### Frontend
- `BACKEND_URL`: URL of the backend service (automatically set in Cloud Run)

### Substitution Variables (Cloud Build)

- `_REGION`: GCP region (default: asia-northeast1)
- `_REPOSITORY`: Artifact Registry repository name (default: reverse-proxy)

## Verification

After deployment, verify the services:

```bash
# Get service URLs
gcloud run services describe reverse-proxy-backend \
  --region=asia-northeast1 \
  --format='value(status.url)'

gcloud run services describe reverse-proxy-frontend \
  --region=asia-northeast1 \
  --format='value(status.url)'

# Test backend
curl $(gcloud run services describe reverse-proxy-backend \
  --region=asia-northeast1 \
  --format='value(status.url)')/api/health

# Test frontend (open in browser)
open $(gcloud run services describe reverse-proxy-frontend \
  --region=asia-northeast1 \
  --format='value(status.url)')
```

## Architecture

```
User → Frontend (Cloud Run)
         ↓ Nginx reverse proxy
         ↓ /api/* requests
       Backend (Cloud Run)
```

- **Frontend**: Flutter Web app served by Nginx
  - Nginx acts as reverse proxy for `/api/*` endpoints
  - Static files served from `/usr/share/nginx/html`
  - Proxies API requests to backend service

- **Backend**: FastAPI application
  - Provides REST API endpoints
  - Returns sample items data

## Cost Optimization

Both services are configured with:
- Minimum instances: 0 (scale to zero when idle)
- Maximum instances: 10
- CPU: 1
- Memory: 512Mi

This configuration minimizes costs by scaling to zero during idle periods.

## Troubleshooting

### Check logs

```bash
# Backend logs
gcloud run services logs read reverse-proxy-backend \
  --region=asia-northeast1 \
  --limit=50

# Frontend logs
gcloud run services logs read reverse-proxy-frontend \
  --region=asia-northeast1 \
  --limit=50
```

### Common issues

1. **Frontend can't connect to backend**
   - Check BACKEND_URL environment variable
   - Verify backend service is deployed and running
   - Check backend service IAM permissions

2. **Build timeout**
   - Increase timeout in cloudbuild.yaml
   - Use faster machine type (already using N1_HIGHCPU_8)

3. **Permission denied**
   - Ensure Cloud Build service account has necessary permissions
   - Grant roles/run.admin to Cloud Build service account

## Cleanup

```bash
# Delete Cloud Run services
gcloud run services delete reverse-proxy-backend --region=asia-northeast1
gcloud run services delete reverse-proxy-frontend --region=asia-northeast1

# Or use Terraform
cd terraform
terraform destroy

# Delete Artifact Registry images (optional)
gcloud artifacts docker images delete \
  asia-northeast1-docker.pkg.dev/${PROJECT_ID}/reverse-proxy/reverse-proxy-backend:latest

gcloud artifacts docker images delete \
  asia-northeast1-docker.pkg.dev/${PROJECT_ID}/reverse-proxy/reverse-proxy-frontend:latest
```

# Frontend Configurations Comparison

This project provides two different frontend configurations to demonstrate different approaches for connecting a Flutter Web frontend with a FastAPI backend on Google Cloud Run.

## Overview

**IMPORTANT**: Both configurations serve the **SAME Flutter Web application**. The application code is identical. The only difference is the **deployment strategy** for handling backend API communication.

| Configuration | Directory | Service Name | Deployment Strategy | Description |
|--------------|-----------|-------------|---------------------|-------------|
| ① Static Only | `frontend-static/` | `reverse-proxy-frontend-static` | `direct-backend-access` | Browser makes direct requests to backend |
| ② Reverse Proxy | `frontend/` | `reverse-proxy-frontend` | `reverse-proxy` | Nginx proxies requests to backend |

### Terraform Module

The Terraform configuration has been refactored to use a reusable module ([terraform/modules/frontend/](terraform/modules/frontend/)) that:
- Encapsulates common frontend deployment logic
- Supports both deployment strategies through configuration
- Makes the difference between the two deployments explicit and clear
- See [terraform/modules/frontend/README.md](terraform/modules/frontend/README.md) for detailed module documentation

---

## Configuration ①: Static File Serving Only

### Architecture

```
Browser → Flutter Web (Static Files) → Backend API
                                       (direct HTTPS request)
```

### How It Works

1. **Build Time**: Flutter Web is built with backend URL as `--dart-define=HOST=<backend-url>`
2. **Runtime**: Nginx simply serves static files (HTML, JS, CSS)
3. **API Requests**: Browser makes direct HTTPS requests to backend from client-side JavaScript

### Directory Structure

```
frontend-static/
├── Dockerfile          # Simple nginx serving static files
├── lib/               # Flutter source code
├── pubspec.yaml       # Flutter dependencies
└── web/               # Web-specific files
```

### Dockerfile Highlights

```dockerfile
# Build Flutter with backend URL
RUN flutter build web --release --dart-define=HOST=${HOST}

# Serve with nginx (port 8080 for Cloud Run)
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
```

### Backend Requirements

- **Must be publicly accessible**: `ingress = "INGRESS_TRAFFIC_ALL"`
- Backend URL must be known at build time
- CORS configuration required on backend

### Pros & Cons

**Pros:**
- Simple architecture
- No additional proxy overhead
- Standard web app deployment pattern

**Cons:**
- Backend must be publicly accessible
- CORS configuration required
- Backend URL cannot be changed without rebuild

---

## Configuration ②: Nginx Reverse Proxy

### Architecture

```
Browser → Frontend Cloud Run Container
            ├── /           → Static Files (Flutter Web)
            └── /api/*      → Nginx Proxy → Backend API
                                             (internal VPC request)
```

### How It Works

1. **Build Time**: Flutter Web is built with relative API path `/api/*`
2. **Runtime**: Nginx configuration is dynamically generated with backend URL from environment variable
3. **API Requests**:
   - Browser makes requests to `/api/*` (same origin, no CORS)
   - Nginx inside Cloud Run container proxies to internal backend

### Directory Structure

```
frontend/
├── Dockerfile              # Multi-stage build with nginx proxy
├── nginx.conf             # Nginx config template with reverse proxy
├── proxy_params_common    # Shared proxy parameters
├── docker-entrypoint.sh   # Dynamic config generation
├── lib/                   # Flutter source code
├── pubspec.yaml          # Flutter dependencies
└── web/                  # Web-specific files
```

### Dockerfile Highlights

```dockerfile
# Build Flutter (HOST can be empty or "/" for relative paths)
RUN flutter build web --release --dart-define=HOST=${HOST}

# Copy nginx config as template
COPY nginx.conf /etc/nginx/nginx.conf.template
COPY proxy_params_common /etc/nginx/proxy_params_common.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
```

### Nginx Configuration

```nginx
# Upstream to backend
upstream backend {
    server BACKEND_HOST_PLACEHOLDER:BACKEND_PORT_PLACEHOLDER;
}

# Proxy /api/* to backend
location /api/ {
    proxy_pass BACKEND_SCHEME_PLACEHOLDER://backend/api/;
    include /etc/nginx/proxy_params_common;
}

# Serve Flutter static files
location / {
    try_files $uri $uri/ /index.html;
}
```

### Backend Requirements

- **Can be internal only**: `ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"`
- No CORS configuration needed
- Backend URL can be changed via environment variable

### Pros & Cons

**Pros:**
- Backend can be internal-only (more secure)
- No CORS issues (same origin)
- Backend URL can be changed without rebuild
- Better for internal APIs

**Cons:**
- More complex architecture
- Additional proxy overhead
- Requires VPC configuration for internal communication

---

## Deployment

### Deploy Both Configurations

```bash
# Deploy backend + both frontends
gcloud builds submit --config=.cloudbuild/cloudbuild.yaml
```

### Deploy Individual Configuration

```bash
# Backend only
./deployment/deploy-backend.sh

# Static only (Configuration ①)
./deployment/deploy-frontend-static.sh

# Reverse proxy (Configuration ②)
./deployment/deploy-frontend-proxy.sh

# Or using gcloud directly:
gcloud builds submit --config=.cloudbuild/frontend-static.yaml
gcloud builds submit --config=.cloudbuild/frontend.yaml
```

### Access URLs

After deployment, get the service URLs:

```bash
# Backend
gcloud run services describe reverse-proxy-backend \
  --region=asia-northeast1 \
  --format='value(status.url)'

# Frontend (Static)
gcloud run services describe reverse-proxy-frontend-static \
  --region=asia-northeast1 \
  --format='value(status.url)'

# Frontend (Proxy)
gcloud run services describe reverse-proxy-frontend \
  --region=asia-northeast1 \
  --format='value(status.url)'
```

---

## Testing Comparison

### Test Backend Accessibility

1. **With Static Frontend**: Backend must respond to browser CORS preflight requests
   ```bash
   curl -H "Origin: https://frontend-static-xxx.run.app" \
        -H "Access-Control-Request-Method: GET" \
        -X OPTIONS \
        https://backend-xxx.run.app/api/hello
   ```

2. **With Proxy Frontend**: Backend can be internal-only, no CORS needed
   ```bash
   # This should fail if backend is INGRESS_TRAFFIC_INTERNAL_ONLY
   curl https://backend-xxx.run.app/api/hello

   # But this works (proxied through frontend)
   curl https://frontend-proxy-xxx.run.app/api/hello
   ```

---

## When to Use Which Configuration

### Use Static Only (①) When:
- Backend is already public
- Simple deployment is preferred
- No VPC setup available
- CORS is acceptable

### Use Reverse Proxy (②) When:
- Backend should be internal-only
- Security is a priority
- VPC networking is available
- Want to avoid CORS complexity
- Backend URL may change

---

## Architecture Diagrams

### Configuration ① (Static Only)

```
┌─────────┐
│ Browser │
└────┬────┘
     │
     ├─── GET /index.html ───────────► ┌──────────────────┐
     │                                  │ Frontend         │
     │                                  │ (Static Nginx)   │
     │◄──────── HTML ───────────────────┤ Cloud Run        │
     │                                  └──────────────────┘
     │
     └─── GET /api/hello ──────────────► ┌──────────────────┐
                                          │ Backend          │
         ◄──────── JSON ───────────────── │ (FastAPI)        │
                                          │ Cloud Run        │
                                          │ PUBLIC           │
                                          └──────────────────┘
```

### Configuration ② (Reverse Proxy)

```
┌─────────┐
│ Browser │
└────┬────┘
     │
     ├─── GET /index.html ───────────► ┌──────────────────────────┐
     │                                  │ Frontend Cloud Run       │
     │◄──────── HTML ──────────────────┤ ┌──────────────────────┐ │
     │                                  │ │ Nginx                │ │
     │                                  │ │ - Static files       │ │
     │                                  │ │ - Reverse proxy      │ │
     │                                  │ └──────────────────────┘ │
     │                                  └──────────────────────────┘
     │
     └─── GET /api/hello ──────────────► ┌──────────────────────────┐
                                          │ Frontend Cloud Run       │
         ◄──────── JSON ───────────────── │ (Nginx proxies request)  │
                                          └─────────┬────────────────┘
                                                    │ Internal Request
                                                    │ (via VPC)
                                                    ▼
                                          ┌──────────────────┐
                                          │ Backend          │
                                          │ (FastAPI)        │
                                          │ Cloud Run        │
                                          │ INTERNAL ONLY    │
                                          └──────────────────┘
```

---

## Summary

This project demonstrates two approaches to connecting Flutter Web with FastAPI on Cloud Run:

- **Static approach** is simpler but requires public backend
- **Proxy approach** is more secure but requires additional configuration

Both approaches are valid, and the choice depends on your specific requirements for security, simplicity, and infrastructure setup.

##########################################
# Configuration ②: Nginx reverse proxy to backend
# Flutter Web app makes requests to /api/* (same origin)
# Nginx (inside Cloud Run container) proxies to internal backend
# This allows backend to be INGRESS_TRAFFIC_INTERNAL_ONLY
##########################################

##########################################
# Build Flutter Web Application
##########################################
FROM instrumentisto/flutter:3.35.0 AS builder

WORKDIR /app

# Copy pubspec files and resolve dependencies
COPY pubspec.* ./
RUN flutter pub get

# Copy source code
COPY . .

# Build Flutter web app
# Note: API calls go to same origin /api/* - nginx proxies to backend
RUN flutter build web --release

##########################################
# Deploy with Nginx (with reverse proxy)
##########################################
FROM nginx:alpine

# Copy Flutter build artifacts
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy Nginx configuration as template
COPY nginx.conf /etc/nginx/nginx.conf.template

# Copy common proxy parameters as template
COPY proxy_params_common /etc/nginx/proxy_params_common.template

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Set permissions for directories required to run nginx
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    # Create temp directories for nginx
    mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R nginx:nginx /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    # Set permissions for nginx.conf template
    chmod 644 /etc/nginx/nginx.conf.template

EXPOSE 80

CMD ["/docker-entrypoint.sh"]

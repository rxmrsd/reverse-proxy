#!/bin/sh
set -e

echo "Starting Nginx with backend proxy configuration..."

# Check if BACKEND_URL is set
if [ -z "$BACKEND_URL" ]; then
    echo "ERROR: BACKEND_URL environment variable is not set"
    exit 1
fi

echo "Backend URL: $BACKEND_URL"

# Extract scheme, host and port from BACKEND_URL
# For http://backend:8000 -> scheme=http, host=backend, port=8000
BACKEND_SCHEME=$(echo "$BACKEND_URL" | sed -E 's|^(https?)://.*|\1|')
BACKEND_HOST=$(echo "$BACKEND_URL" | sed -E 's|^https?://([^:/]+).*|\1|')
BACKEND_PORT=$(echo "$BACKEND_URL" | sed -E 's|^https?://[^:]+:([0-9]+).*|\1|')

# If port extraction failed (no port in URL), use default based on protocol
if [ "$BACKEND_PORT" = "$BACKEND_URL" ]; then
    if [ "$BACKEND_SCHEME" = "https" ]; then
        BACKEND_PORT=443
    else
        BACKEND_PORT=80
    fi
fi

echo "Backend Scheme: $BACKEND_SCHEME"
echo "Backend Host: $BACKEND_HOST"
echo "Backend Port: $BACKEND_PORT"

# Substitute BACKEND_SCHEME, BACKEND_HOST, and BACKEND_PORT in nginx configuration
sed -e "s|BACKEND_SCHEME_PLACEHOLDER|$BACKEND_SCHEME|g" \
    -e "s|BACKEND_HOST_PLACEHOLDER|$BACKEND_HOST|g" \
    -e "s|BACKEND_PORT_PLACEHOLDER|$BACKEND_PORT|g" \
    /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Substitute BACKEND_HOST in proxy_params_common
sed -e "s|BACKEND_HOST_PLACEHOLDER|$BACKEND_HOST|g" \
    /etc/nginx/proxy_params_common.template > /etc/nginx/proxy_params_common

echo "Nginx configuration updated successfully"
echo "================================"
cat /etc/nginx/nginx.conf
echo "================================"

# Start nginx
echo "Starting Nginx..."
exec nginx -g "daemon off;"

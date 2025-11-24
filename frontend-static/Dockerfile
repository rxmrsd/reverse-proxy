##########################################
# Configuration ①: Static file serving only
# Flutter Web app makes direct requests to backend from browser
# Backend must be publicly accessible for this to work
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
# Note: No HOST configuration needed - browser makes direct requests to backend
RUN flutter build web --release

##########################################
# Deploy with Nginx (static file serving only)
##########################################
FROM nginx:alpine

# Copy Flutter build artifacts
COPY --from=builder /app/build/web /usr/share/nginx/html

# Change nginx port from 80 to 8080 (Cloud Run requirement)
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

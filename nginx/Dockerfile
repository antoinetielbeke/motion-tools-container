# syntax=docker/dockerfile:1
ARG NGINX_VERSION=1.29-alpine3.22-otel
ARG ANTRAGSGRUEN_VERSION=v4.12.4

FROM nginx:${NGINX_VERSION}

ARG ANTRAGSGRUEN_VERSION
LABEL org.opencontainers.image.title="Motion Tools - NGINX" \
      org.opencontainers.image.description="NGINX container for Antragsgruen (Motion Tools) with OpenTelemetry support" \
      org.opencontainers.image.version="${ANTRAGSGRUEN_VERSION}" \
      org.opencontainers.image.source="https://github.com/yourusername/motion-tools-container" \
      org.opencontainers.image.licenses="MIT"

# Install additional tools
RUN apk add --no-cache \
    gettext \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Copy NGINX configuration templates
# Note: nginx.conf is provided by base image, we only customize server blocks
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.d/40-motion-tools-setup.sh

# Make entrypoint executable
RUN chmod +x /docker-entrypoint.d/40-motion-tools-setup.sh

# Create directory for static files (shared with PHP-FPM)
RUN mkdir -p /var/www/html/web \
    && chown -R nginx:nginx /var/www/html

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1

# Use default nginx entrypoint which processes templates
# ENTRYPOINT and CMD are inherited from base nginx image

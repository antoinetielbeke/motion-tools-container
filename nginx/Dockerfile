# syntax=docker/dockerfile:1
ARG NGINX_VERSION=1.27-alpine-otel
ARG ANTRAGSGRUEN_VERSION=v4.17-volt

FROM nginx:${NGINX_VERSION}

ARG ANTRAGSGRUEN_VERSION
LABEL org.opencontainers.image.title="Motion Tools NGINX" \
      org.opencontainers.image.description="NGINX container for Antragsgruen with OpenTelemetry support" \
      org.opencontainers.image.version="${ANTRAGSGRUEN_VERSION}" \
      org.opencontainers.image.source="https://github.com/CatoTH/antragsgruen"

RUN apk add --no-cache gettext netcat-openbsd \
    && sed -i '1i load_module modules/ngx_otel_module.so;' /etc/nginx/nginx.conf

COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY otel.conf.template /etc/nginx/templates/otel.conf.template
COPY 00-logging.conf.template /etc/nginx/templates/00-logging.conf.template
COPY 15-otel-setup.envsh /docker-entrypoint.d/15-otel-setup.envsh
COPY docker-entrypoint.sh /docker-entrypoint.d/40-motion-tools-setup.sh

RUN chmod +x /docker-entrypoint.d/15-otel-setup.envsh \
    && chmod +x /docker-entrypoint.d/40-motion-tools-setup.sh \
    && mkdir -p /var/www/html/web \
    && chown -R nginx:nginx /var/www/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

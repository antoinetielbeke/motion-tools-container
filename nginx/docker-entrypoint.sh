#!/bin/sh
set -e

echo "[nginx-entrypoint] Motion Tools NGINX container starting"

# Set default values for environment variables if not set
export PHP_FPM_HOST="${PHP_FPM_HOST:-php-fpm}"
export PHP_FPM_PORT="${PHP_FPM_PORT:-9000}"
export NGINX_PORT="${NGINX_PORT:-80}"
export NGINX_SERVER_NAME="${NGINX_SERVER_NAME:-_}"
export NGINX_WORKER_PROCESSES="${NGINX_WORKER_PROCESSES:-auto}"
export NGINX_WORKER_CONNECTIONS="${NGINX_WORKER_CONNECTIONS:-2048}"
export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-32M}"
export NGINX_LOG_LEVEL="${NGINX_LOG_LEVEL:-warn}"
export NGINX_LOG_FORMAT="${NGINX_LOG_FORMAT:-main}"

# Wait for PHP-FPM to be ready (optional)
if [ "${WAIT_FOR_PHP_FPM}" = "true" ]; then
    echo "[nginx-entrypoint] Waiting for PHP-FPM at ${PHP_FPM_HOST}:${PHP_FPM_PORT}"
    timeout=60
    while ! nc -z ${PHP_FPM_HOST} ${PHP_FPM_PORT} 2>/dev/null; do
        timeout=$((timeout - 1))
        if [ $timeout -le 0 ]; then
            echo "[nginx-entrypoint] ERROR: Timeout waiting for PHP-FPM"
            exit 1
        fi
        echo "[nginx-entrypoint] Waiting for PHP-FPM... ($timeout seconds remaining)"
        sleep 1
    done
    echo "[nginx-entrypoint] PHP-FPM is ready"
fi

# Display configuration
echo "[nginx-entrypoint] Configuration:"
echo "  - PHP-FPM Backend: ${PHP_FPM_HOST}:${PHP_FPM_PORT}"
echo "  - Listen Port: ${NGINX_PORT}"
echo "  - Server Name: ${NGINX_SERVER_NAME}"
echo "  - Worker Processes: ${NGINX_WORKER_PROCESSES}"
echo "  - Worker Connections: ${NGINX_WORKER_CONNECTIONS}"
echo "  - Client Max Body Size: ${NGINX_CLIENT_MAX_BODY_SIZE}"
echo "  - Log Level: ${NGINX_LOG_LEVEL}"

# Test NGINX configuration
echo "[nginx-entrypoint] Testing NGINX configuration"
nginx -t

echo "[nginx-entrypoint] NGINX configuration is valid"
echo "[nginx-entrypoint] Starting NGINX"

# The default nginx entrypoint will handle the rest

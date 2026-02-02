#!/bin/sh
set -e

echo "[nginx] Motion Tools NGINX"

export PHP_FPM_HOST="${PHP_FPM_HOST:-php-fpm}"
export PHP_FPM_PORT="${PHP_FPM_PORT:-9000}"
export NGINX_SERVER_NAME="${NGINX_SERVER_NAME:-_}"
export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-32M}"
export NGINX_FASTCGI_CONNECT_TIMEOUT="${NGINX_FASTCGI_CONNECT_TIMEOUT:-60s}"
export NGINX_FASTCGI_SEND_TIMEOUT="${NGINX_FASTCGI_SEND_TIMEOUT:-300s}"
export NGINX_FASTCGI_READ_TIMEOUT="${NGINX_FASTCGI_READ_TIMEOUT:-300s}"

if [ "${WAIT_FOR_PHP_FPM}" = "true" ]; then
    echo "[nginx] Waiting for PHP-FPM at ${PHP_FPM_HOST}:${PHP_FPM_PORT}"
    timeout=60
    while ! nc -z ${PHP_FPM_HOST} ${PHP_FPM_PORT} 2>/dev/null; do
        timeout=$((timeout - 1))
        if [ $timeout -le 0 ]; then
            echo "[nginx] ERROR: Timeout waiting for PHP-FPM"
            exit 1
        fi
        sleep 1
    done
    echo "[nginx] PHP-FPM is ready"
fi

echo "[nginx] Backend: ${PHP_FPM_HOST}:${PHP_FPM_PORT}"

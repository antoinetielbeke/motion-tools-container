#!/bin/sh
set -e

echo "[entrypoint] Starting Motion Tools PHP-FPM container"

# Function to substitute environment variables in templates
envsubst_template() {
    local template_file="$1"
    local output_file="$2"

    if [ -f "$template_file" ]; then
        echo "[entrypoint] Processing template: $template_file -> $output_file"
        # Use envsubst to replace environment variables
        # If envsubst is not available, use a simple sed-based approach
        if command -v envsubst >/dev/null 2>&1; then
            envsubst < "$template_file" > "$output_file"
        else
            # Fallback: process common variables
            sed -e "s/\${PHP_MEMORY_LIMIT:-512M}/${PHP_MEMORY_LIMIT:-512M}/g" \
                -e "s/\${PHP_MAX_EXECUTION_TIME:-300}/${PHP_MAX_EXECUTION_TIME:-300}/g" \
                -e "s/\${PHP_UPLOAD_MAX_FILESIZE:-32M}/${PHP_UPLOAD_MAX_FILESIZE:-32M}/g" \
                -e "s/\${PHP_POST_MAX_SIZE:-40M}/${PHP_POST_MAX_SIZE:-40M}/g" \
                -e "s/\${PHP_TIMEZONE:-UTC}/${PHP_TIMEZONE:-UTC}/g" \
                "$template_file" > "$output_file"
        fi
    fi
}

# Create necessary directories with proper permissions
echo "[entrypoint] Creating required directories"
mkdir -p \
    /var/www/html/runtime/backups \
    /var/www/html/runtime/cache \
    /var/www/html/runtime/logs \
    /var/www/html/runtime/sessions \
    /var/www/html/web/assets \
    /var/www/html/config

# Ensure directories are writable
chmod -R 775 /var/www/html/runtime /var/www/html/web/assets 2>/dev/null || true
chmod 775 /var/www/html/config 2>/dev/null || true

# Process PHP configuration template
if [ -f /usr/local/etc/php/conf.d/zz-antragsgruen.ini.template ]; then
    echo "[entrypoint] Processing PHP configuration template"
    envsubst_template \
        /usr/local/etc/php/conf.d/zz-antragsgruen.ini.template \
        /usr/local/etc/php/conf.d/zz-antragsgruen.ini
fi

# Process PHP-FPM configuration template
if [ -f /usr/local/etc/php-fpm.d/zz-antragsgruen.conf.template ]; then
    echo "[entrypoint] Processing PHP-FPM configuration template"
    envsubst_template \
        /usr/local/etc/php-fpm.d/zz-antragsgruen.conf.template \
        /usr/local/etc/php-fpm.d/zz-antragsgruen.conf
fi

# Configure msmtp for mail sending
if [ -n "$SMTP_HOST" ]; then
    echo "[entrypoint] Configuring msmtp for SMTP"
    envsubst_template /etc/msmtprc.template /etc/msmtprc
    chmod 600 /etc/msmtprc

    # Configure PHP to use msmtp as sendmail
    echo "sendmail_path = \"/usr/bin/msmtp -t\"" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini
fi

# Configure Symfony Mailer DSN if not already set
if [ -z "$MAILER_DSN" ] && [ -n "$SMTP_HOST" ]; then
    # Build Symfony Mailer DSN from individual SMTP settings
    SMTP_SCHEME="${SMTP_SCHEME:-smtp}"
    SMTP_PORT="${SMTP_PORT:-587}"

    if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASSWORD" ]; then
        export MAILER_DSN="${SMTP_SCHEME}://${SMTP_USER}:${SMTP_PASSWORD}@${SMTP_HOST}:${SMTP_PORT}"
    else
        export MAILER_DSN="${SMTP_SCHEME}://${SMTP_HOST}:${SMTP_PORT}"
    fi

    echo "[entrypoint] Configured MAILER_DSN for Symfony Mailer"
fi

# Initialize config.json from template if it doesn't exist
if [ ! -f /var/www/html/config/config.json ]; then
    if [ -f /usr/local/etc/config.json.template ]; then
        echo "[entrypoint] Generating config.json from template"
        # Set defaults for required variables if not provided
        export DB_HOST="${DB_HOST:-db}"
        export DB_NAME="${DB_NAME:-antragsgruen}"
        export DB_USER="${DB_USER:-antragsgruen}"
        export REDIS_HOST="${REDIS_HOST:-redis}"
        export REDIS_PORT="${REDIS_PORT:-6379}"
        export REDIS_DB="${REDIS_DB:-0}"
        export DOMAIN="${DOMAIN:-localhost:8080}"
        export PROTOCOL="${PROTOCOL:-http}"
        export MULTISITE_MODE="${MULTISITE_MODE:-false}"
        export PREPEND_WWW="${PREPEND_WWW:-false}"
        export BASE_LANGUAGE="${BASE_LANGUAGE:-en}"
        export MAIL_FROM_EMAIL="${MAIL_FROM_EMAIL:-noreply@localhost}"
        export MAIL_FROM_NAME="${MAIL_FROM_NAME:-Antragsgruen}"
        export SMTP_HOST="${SMTP_HOST:-mailhog}"
        export SMTP_PORT="${SMTP_PORT:-1025}"
        export SMTP_AUTH_TYPE="${SMTP_AUTH_TYPE:-none}"
        export SMTP_USERNAME="${SMTP_USERNAME:-}"
        export SMTP_PASSWORD="${SMTP_PASSWORD:-}"
        export XELATEX_PATH="${XELATEX_PATH:-}"
        export XDVIPDFMX_PATH="${XDVIPDFMX_PATH:-}"
        export PDFUNITE_PATH="${PDFUNITE_PATH:-}"
        
        # Generate config.json using envsubst with explicit variable list
        envsubst '${DB_HOST} ${DB_NAME} ${DB_USER} ${DB_PASSWORD} ${REDIS_HOST} ${REDIS_PORT} ${REDIS_DB} ${MULTISITE_MODE} ${DOMAIN} ${PREPEND_WWW} ${PROTOCOL} ${BASE_LANGUAGE} ${RANDOM_SEED} ${MAIL_FROM_EMAIL} ${MAIL_FROM_NAME} ${SMTP_HOST} ${SMTP_PORT} ${SMTP_AUTH_TYPE} ${SMTP_USERNAME} ${SMTP_PASSWORD} ${XELATEX_PATH} ${XDVIPDFMX_PATH} ${PDFUNITE_PATH}' \
            < /usr/local/etc/config.json.template > /var/www/html/config/config.json
        
        # For single-site mode, add siteSubdomain configuration
        if [ "$ANTRAGSGRUEN_MODE" = "single-site" ]; then
            echo "[entrypoint] Configuring for single-site mode"
            # Use jq-like sed to add siteSubdomain after multisiteMode
            # For single-site: use simple domain paths and specify which site subdomain to load
            sed -i 's/"multisiteMode": false,/"multisiteMode": false,\n    "siteSubdomain": "std",/' /var/www/html/config/config.json
            sed -i 's|"domainPlain": ".*"|"domainPlain": "/"|' /var/www/html/config/config.json
            sed -i 's|"domainSubdomain": ".*"|"domainSubdomain": ""|' /var/www/html/config/config.json
            sed -i 's|"resourceBase": ".*"|"resourceBase": "/"|' /var/www/html/config/config.json
        fi
        
        chmod 664 /var/www/html/config/config.json
        echo "[entrypoint] config.json generated successfully"
    elif [ -n "$ANTRAGSGRUEN_CONFIG_JSON" ]; then
        echo "[entrypoint] Initializing config.json from ANTRAGSGRUEN_CONFIG_JSON (deprecated)"
        echo "$ANTRAGSGRUEN_CONFIG_JSON" > /var/www/html/config/config.json
        chmod 664 /var/www/html/config/config.json
    else
        echo "[entrypoint] ERROR: config.json not found and no template available."
        echo "[entrypoint] Please provide configuration via template or ANTRAGSGRUEN_CONFIG_JSON."
        exit 1
    fi
else
    echo "[entrypoint] Using existing config.json"
fi

# Initialize database if AUTO_INIT_DB is enabled (default: true for development)
if [ "${AUTO_INIT_DB:-true}" = "true" ]; then
    if [ -f /usr/local/bin/init-db.sh ]; then
        echo "[entrypoint] Running database initialization"
        . /usr/local/bin/init-db.sh
    else
        echo "[entrypoint] WARNING: init-db.sh not found, skipping database initialization"
    fi
else
    echo "[entrypoint] Database auto-initialization disabled (AUTO_INIT_DB=false)"
fi

# Run database migrations if requested
if [ "$RUN_MIGRATIONS" = "true" ] || [ "$RUN_MIGRATIONS" = "1" ]; then
    echo "[entrypoint] Running database migrations"
    php /var/www/html/yii migrate --interactive=0 || echo "[entrypoint] WARNING: Migration failed"
fi

# Display configuration summary
echo "[entrypoint] Configuration summary:"
echo "  - PHP Version: $(php -v | head -n 1)"
echo "  - PHP Memory Limit: ${PHP_MEMORY_LIMIT:-512M}"
echo "  - Upload Max Filesize: ${PHP_UPLOAD_MAX_FILESIZE:-32M}"
echo "  - Timezone: ${PHP_TIMEZONE:-UTC}"
echo "  - SMTP Host: ${SMTP_HOST:-not configured}"
echo "  - Mailer DSN: ${MAILER_DSN:+configured}"
echo "  - Database Host: ${DB_HOST:-not set}"
echo "  - Redis Host: ${REDIS_HOST:-not configured}"

echo "[entrypoint] Starting PHP-FPM (will drop to www-data internally)"
# PHP-FPM starts as root and drops to www-data via its own configuration
exec "$@"

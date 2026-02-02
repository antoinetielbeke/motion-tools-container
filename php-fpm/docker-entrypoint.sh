#!/bin/sh
set -e

echo "[entrypoint] Motion Tools PHP-FPM (Antragsgruen v4.17-volt)"

if [ -z "$RANDOM_SEED" ]; then
    echo "[entrypoint] ERROR: RANDOM_SEED environment variable is required!"
    echo "[entrypoint] Generate with: openssl rand -base64 32"
    exit 1
fi

mkdir -p /var/www/html/runtime/cache /var/www/html/runtime/logs /var/www/html/web/assets
chmod -R 775 /var/www/html/runtime /var/www/html/web/assets 2>/dev/null || true

if [ -n "$DB_HOST" ]; then
    echo "[entrypoint] Waiting for database at ${DB_HOST}:${DB_PORT:-3306}..."
    timeout=60
    while ! nc -z "$DB_HOST" "${DB_PORT:-3306}" 2>/dev/null; do
        timeout=$((timeout - 1))
        if [ $timeout -le 0 ]; then
            echo "[entrypoint] ERROR: Database connection timeout"
            exit 1
        fi
        sleep 1
    done
    echo "[entrypoint] Database is ready"

    if [ "$RUN_MIGRATIONS" = "true" ] || [ "$RUN_MIGRATIONS" = "1" ]; then
        TABLE_PREFIX="${TABLE_PREFIX:-${DB_TABLE_PREFIX:-}}"
        
        TABLE_CHECK=$(mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -N -e "SHOW TABLES LIKE '${TABLE_PREFIX}site';" 2>/dev/null || true)
        
        if [ -z "$TABLE_CHECK" ]; then
            echo "[entrypoint] Fresh install detected - importing base schema..."
            
            sed "s/###TABLE_PREFIX###/${TABLE_PREFIX}/g" /var/www/html/assets/db/create.sql | \
                mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
            
            if [ $? -eq 0 ]; then
                echo "[entrypoint] Base schema imported successfully"
                
                echo "[entrypoint] Marking all migrations as applied..."
                for migration in /var/www/html/migrations/m*.php; do
                    migration_name=$(basename "$migration" .php)
                    mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
                        "INSERT IGNORE INTO ${TABLE_PREFIX}migration (version, apply_time) VALUES ('$migration_name', UNIX_TIMESTAMP());" 2>/dev/null || true
                done
                echo "[entrypoint] Migrations marked as applied"

                if [ "$MULTISITE_MODE" != "true" ] && [ "$MULTISITE_MODE" != "1" ]; then
                    echo "[entrypoint] Single-site mode: creating default site..."
                    mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
                        "INSERT INTO ${TABLE_PREFIX}site (id, subdomain, title, organization, status, dateCreation) VALUES (1, 'std', 'Demo Site', '', 0, NOW());"
                    mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
                        "INSERT INTO ${TABLE_PREFIX}consultation (id, siteId, urlPath, wordingBase, title, titleShort, amendmentNumbering, dateCreation, adminEmail, settings) VALUES (1, 1, 'main', '${BASE_LANGUAGE:-en}', 'Main Consultation', 'Main', 0, NOW(), '', '{}');"
                    echo "[entrypoint] Default site created"
                fi
            else
                echo "[entrypoint] ERROR: Failed to import base schema"
                exit 1
            fi
        else
            echo "[entrypoint] Database already initialized, running migrations..."
            php /var/www/html/yii migrate --interactive=0 || {
                echo "[entrypoint] WARNING: Migration failed"
            }
        fi
    fi
fi

echo "[entrypoint] Configuration (env vars only, no config.json):"
echo "  DB_HOST: ${DB_HOST:-not set}"
echo "  REDIS_HOST: ${REDIS_HOST:-not set}"
echo "  APP_DOMAIN: ${APP_DOMAIN:-not set}"
echo "  MULTISITE_MODE: ${MULTISITE_MODE:-false}"

echo "[entrypoint] Starting PHP-FPM"
exec "$@"

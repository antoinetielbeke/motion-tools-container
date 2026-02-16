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
                    # Use configurable values with sensible defaults
                    SITE_SUBDOMAIN="${SITE_SUBDOMAIN:-std}"
                    SITE_TITLE="${SITE_TITLE:-Demo Site}"
                    CONSULTATION_PATH="${CONSULTATION_PATH:-main}"
                    CONSULTATION_TITLE="${CONSULTATION_TITLE:-Main Consultation}"
                    CONSULTATION_TITLE_SHORT="${CONSULTATION_TITLE_SHORT:-Main}"

                    echo "[entrypoint] Single-site mode: creating default site..."
                    echo "[entrypoint]   Site subdomain: $SITE_SUBDOMAIN"
                    echo "[entrypoint]   Consultation path: /$CONSULTATION_PATH"

                    mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
                        "INSERT INTO ${TABLE_PREFIX}site (id, subdomain, title, organization, status, dateCreation) VALUES (1, '$SITE_SUBDOMAIN', '$SITE_TITLE', '', 0, NOW());"
                    mariadb -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
                        "INSERT INTO ${TABLE_PREFIX}consultation (id, siteId, urlPath, wordingBase, title, titleShort, amendmentNumbering, dateCreation, adminEmail, settings) VALUES (1, 1, '$CONSULTATION_PATH', '${BASE_LANGUAGE:-en}', '$CONSULTATION_TITLE', '$CONSULTATION_TITLE_SHORT', 0, NOW(), '', '{}');"
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

# Create minimal config.json for v4.17-volt environment variable support
# The file must exist (index.php check), but can be empty - all config comes from env vars
if [ ! -f /var/www/html/config/config.json ]; then
    echo "[entrypoint] Creating minimal config.json for environment-only configuration..."

    if [ "$MULTISITE_MODE" = "true" ] || [ "$MULTISITE_MODE" = "1" ]; then
        # Multisite mode: empty config, everything from env vars
        echo '{}' > /var/www/html/config/config.json
    else
        # Single-site mode: need siteSubdomain in config.json (no env var available for this)
        # Use SITE_SUBDOMAIN env var with 'std' as default
        SITE_SUBDOMAIN="${SITE_SUBDOMAIN:-std}"
        cat > /var/www/html/config/config.json << EOF
{
  "multisiteMode": false,
  "siteSubdomain": "$SITE_SUBDOMAIN"
}
EOF
    fi
    echo "[entrypoint] config.json created (all other settings from environment variables)"
fi

# OIDC Configuration
if [ "$OIDC_ENABLED" = "true" ] || [ "$OIDC_ENABLED" = "1" ]; then
    echo "[entrypoint] Configuring OIDC authentication..."

    # Validate required variables
    missing_vars=""
    [ -z "$OIDC_CLIENT_ID" ] && missing_vars="$missing_vars OIDC_CLIENT_ID"
    [ -z "$OIDC_CLIENT_SECRET" ] && missing_vars="$missing_vars OIDC_CLIENT_SECRET"
    [ -z "$OIDC_ISSUER" ] && missing_vars="$missing_vars OIDC_ISSUER"

    if [ -n "$missing_vars" ]; then
        echo "[entrypoint] ERROR: Missing required OIDC variables:$missing_vars"
        exit 1
    fi

    # Set defaults for optional variables
    OIDC_REDIRECT_URI="${OIDC_REDIRECT_URI:-${APP_PROTOCOL:-https}://${APP_DOMAIN}/sso-callback}"
    OIDC_SCOPES="${OIDC_SCOPES:-openid,profile,email}"
    OIDC_PKCE="${OIDC_PKCE:-true}"
    OIDC_SINGLE_LOGOUT="${OIDC_SINGLE_LOGOUT:-true}"
    OIDC_SYNC_GROUPS="${OIDC_SYNC_GROUPS:-false}"
    OIDC_DISCOVERY="${OIDC_DISCOVERY:-true}"

    # Attribute mapping defaults
    OIDC_ATTR_EMAIL="${OIDC_ATTR_EMAIL:-email}"
    OIDC_ATTR_USERNAME="${OIDC_ATTR_USERNAME:-preferred_username}"
    OIDC_ATTR_GIVEN_NAME="${OIDC_ATTR_GIVEN_NAME:-given_name}"
    OIDC_ATTR_FAMILY_NAME="${OIDC_ATTR_FAMILY_NAME:-family_name}"
    OIDC_ATTR_GROUPS="${OIDC_ATTR_GROUPS:-groups}"
    OIDC_GROUP_MAPPING="${OIDC_GROUP_MAPPING:-{\}}"

    # OIDC Discovery - fetch endpoints from .well-known/openid-configuration
    if [ "$OIDC_DISCOVERY" = "true" ] || [ "$OIDC_DISCOVERY" = "1" ]; then
        echo "[entrypoint] Fetching OIDC discovery document from $OIDC_ISSUER..."
        DISCOVERY_URL="${OIDC_ISSUER}/.well-known/openid-configuration"

        DISCOVERY_DOC=$(curl -sf --connect-timeout 10 --max-time 30 "$DISCOVERY_URL") || {
            echo "[entrypoint] ERROR: Failed to fetch OIDC discovery document from $DISCOVERY_URL"
            exit 1
        }

        # Extract endpoints from discovery document (only if not explicitly set)
        [ -z "$OIDC_URL_AUTHORIZE" ] && OIDC_URL_AUTHORIZE=$(echo "$DISCOVERY_DOC" | jq -r '.authorization_endpoint // empty')
        [ -z "$OIDC_URL_TOKEN" ] && OIDC_URL_TOKEN=$(echo "$DISCOVERY_DOC" | jq -r '.token_endpoint // empty')
        [ -z "$OIDC_URL_USERINFO" ] && OIDC_URL_USERINFO=$(echo "$DISCOVERY_DOC" | jq -r '.userinfo_endpoint // empty')
        [ -z "$OIDC_URL_LOGOUT" ] && OIDC_URL_LOGOUT=$(echo "$DISCOVERY_DOC" | jq -r '.end_session_endpoint // empty')

        echo "[entrypoint] OIDC endpoints discovered successfully"
    fi

    # Validate we have required endpoints
    if [ -z "$OIDC_URL_AUTHORIZE" ] || [ -z "$OIDC_URL_TOKEN" ]; then
        echo "[entrypoint] ERROR: Missing OIDC endpoints. Either enable discovery or set OIDC_URL_AUTHORIZE and OIDC_URL_TOKEN"
        exit 1
    fi

    # Convert boolean strings to JSON booleans
    pkce_json="true"
    [ "$OIDC_PKCE" = "false" ] || [ "$OIDC_PKCE" = "0" ] && pkce_json="false"

    single_logout_json="true"
    [ "$OIDC_SINGLE_LOGOUT" = "false" ] || [ "$OIDC_SINGLE_LOGOUT" = "0" ] && single_logout_json="false"

    sync_groups_json="false"
    [ "$OIDC_SYNC_GROUPS" = "true" ] || [ "$OIDC_SYNC_GROUPS" = "1" ] && sync_groups_json="true"

    # Convert comma-separated scopes to JSON array
    SCOPES_JSON=$(echo "$OIDC_SCOPES" | tr ',' '\n' | jq -R . | jq -s .)

    # Generate config/generic_sso.json
    SSO_CONFIG_FILE="/var/www/html/config/generic_sso.json"

    cat > "$SSO_CONFIG_FILE" <<SSOEOF
{
  "enabled": true,
  "protocol": "oidc",
  "providerId": "generic-sso",
  "singleLogout": $single_logout_json,
  "syncGroups": $sync_groups_json,
  "oidc": {
    "clientId": $(echo "$OIDC_CLIENT_ID" | jq -R .),
    "clientSecret": $(echo "$OIDC_CLIENT_SECRET" | jq -R .),
    "redirectUri": $(echo "$OIDC_REDIRECT_URI" | jq -R .),
    "urlAuthorize": $(echo "$OIDC_URL_AUTHORIZE" | jq -R .),
    "urlAccessToken": $(echo "$OIDC_URL_TOKEN" | jq -R .),
    "urlUserInfo": $(echo "$OIDC_URL_USERINFO" | jq -R .),
    "urlLogout": $(echo "$OIDC_URL_LOGOUT" | jq -R .),
    "issuer": $(echo "$OIDC_ISSUER" | jq -R .),
    "scopes": $SCOPES_JSON,
    "pkce": $pkce_json
  },
  "attributeMapping": {
    "email": $(echo "$OIDC_ATTR_EMAIL" | jq -R .),
    "username": $(echo "$OIDC_ATTR_USERNAME" | jq -R .),
    "givenName": $(echo "$OIDC_ATTR_GIVEN_NAME" | jq -R .),
    "familyName": $(echo "$OIDC_ATTR_FAMILY_NAME" | jq -R .)$([ "$sync_groups_json" = "true" ] && echo ",
    \"groups\": $(echo "$OIDC_ATTR_GROUPS" | jq -R .)")
  },
  "groupMapping": $OIDC_GROUP_MAPPING
}
SSOEOF

    # Set proper file permissions (readable by www-data, not world-readable)
    chmod 640 "$SSO_CONFIG_FILE"
    chown www-data:www-data "$SSO_CONFIG_FILE"

    echo "[entrypoint] OIDC configuration written to $SSO_CONFIG_FILE"
fi

echo "[entrypoint] Configuration mode: environment variables + minimal config.json"
echo "  DB_HOST: ${DB_HOST:-not set}"
echo "  REDIS_HOST: ${REDIS_HOST:-not set}"
echo "  APP_DOMAIN: ${APP_DOMAIN:-not set}"
echo "  MULTISITE_MODE: ${MULTISITE_MODE:-false}"
echo "  OIDC_ENABLED: ${OIDC_ENABLED:-false}"

echo "[entrypoint] Starting PHP-FPM"
exec "$@"

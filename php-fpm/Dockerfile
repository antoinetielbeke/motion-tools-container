# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.4
ARG ANTRAGSGRUEN_VERSION=v4.17-volt

FROM php:${PHP_VERSION}-fpm-alpine AS builder

ARG ANTRAGSGRUEN_VERSION

RUN apk add --no-cache \
    git \
    nodejs \
    npm \
    autoconf \
    g++ \
    make \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libxml2-dev \
    oniguruma-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        pdo_mysql \
        opcache \
        zip \
        bcmath \
        exif \
        mysqli \
        xml \
        mbstring

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /build

RUN git clone --depth 1 --branch ${ANTRAGSGRUEN_VERSION} \
    https://github.com/CatoTH/antragsgruen.git . \
    && rm -rf .git

# Move league/oauth2-client from "suggest" to "require" before resolving
# dependencies (upstream has it as optional but the generic_sso OIDC plugin
# needs it at runtime).  Editing composer.json then deleting the lock lets
# composer install do a single clean resolve without hitting the GitHub API
# (which fails in CI without a token).
RUN php -r ' \
    $j = json_decode(file_get_contents("composer.json"), true); \
    $j["require"]["league/oauth2-client"] = "^2.7"; \
    file_put_contents("composer.json", json_encode($j, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n"); \
    ' \
    && rm -f composer.lock

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --prefer-dist

RUN npm ci --production=false \
    && npm run build \
    && rm -rf node_modules \
    && npm cache clean --force

RUN mkdir -p runtime/cache runtime/logs web/assets \
    && chmod -R 777 runtime web/assets

FROM php:${PHP_VERSION}-fpm-alpine AS runtime

ARG ANTRAGSGRUEN_VERSION
LABEL org.opencontainers.image.title="Motion Tools PHP-FPM" \
      org.opencontainers.image.description="PHP-FPM container for Antragsgruen with 12-factor env var support" \
      org.opencontainers.image.version="${ANTRAGSGRUEN_VERSION}" \
      org.opencontainers.image.source="https://github.com/CatoTH/antragsgruen"

RUN apk add --no-cache \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    icu \
    icu-data-full \
    libxml2 \
    oniguruma \
    imagemagick \
    weasyprint \
    poppler-utils \
    mysql-client \
    netcat-openbsd \
    fcgi \
    jq \
    curl

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=builder --chown=www-data:www-data /build /var/www/html

# Patch: Allow SSO to link existing local accounts by email (opt-in via OIDC_LINK_BY_EMAIL env var).
# When enabled, if no user is found by the SSO auth key, fall back to matching by email and re-link.
# This is safe only when the IdP guarantees verified emails (e.g. Logto, Azure AD, Google).
RUN php -r ' \
    $file = "/var/www/html/plugins/generic_sso/SsoLogin.php"; \
    $code = file_get_contents($file); \
    $old = "\$user = User::findOne([\x27auth\x27 => \$auth]);\n\n        if (!\$user) {\n            \$user = new User();"; \
    $new = "\$user = User::findOne([\x27auth\x27 => \$auth]);\n\n        // Email-based account linking (opt-in via OIDC_LINK_BY_EMAIL env var)\n        // When enabled, existing local accounts are linked to the SSO identity on first SSO login.\n        // Only safe when the identity provider guarantees verified email addresses.\n        if (!\$user && getenv(\x27OIDC_LINK_BY_EMAIL\x27) === \x27true\x27 && !empty(\$userData[\x27email\x27])) {\n            \$user = User::findOne([\x27email\x27 => \$userData[\x27email\x27]]);\n            if (\$user) {\n                \\Yii::info(\x27SSO: Linking existing account \x27 . \$userData[\x27email\x27] . \x27 to auth \x27 . \$auth, \x27generic_sso\x27);\n                \$user->auth = \$auth;\n            }\n        }\n\n        if (!\$user) {\n            \$user = new User();"; \
    if (strpos($code, $old) === false) { echo "ERROR: patch target not found\n"; exit(1); } \
    file_put_contents($file, str_replace($old, $new, $code)); \
    echo "Patched SsoLogin.php with email-based account linking\n"; \
    '

# Patch: Fix SSO LoginController to not catch Yii ExitException during OIDC redirect
RUN sed -i 's/} catch (\\Exception $e) {/} catch (\\yii\\base\\ExitException $e) {\n            throw $e;\n        } catch (\\Exception $e) {/' \
    /var/www/html/plugins/generic_sso/controllers/LoginController.php

# Patch: Fix Base.php to handle null currentConsultation when consultationId is empty
# (happens on SSO callback URL /sso-callback which has no consultation path prefix)
RUN sed -i 's/$consultationId = $this->site->currentConsultation->urlPath;/$consultationId = $this->site->currentConsultation ? $this->site->currentConsultation->urlPath : "";/' \
    /var/www/html/controllers/Base.php

RUN echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini \
    && echo "upload_max_filesize=32M" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini \
    && echo "post_max_size=40M" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini \
    && echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/zz-antragsgruen.ini

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/var/www/html/runtime", "/var/www/html/web/assets"]

WORKDIR /var/www/html

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]

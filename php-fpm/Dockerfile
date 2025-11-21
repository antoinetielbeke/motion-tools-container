# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.3
ARG ANTRAGSGRUEN_VERSION=v4.16.0

###############################################################################
# Builder Stage: Build Antragsgruen with all dependencies
###############################################################################
FROM php:${PHP_VERSION}-fpm-alpine AS builder

ARG ANTRAGSGRUEN_VERSION
ARG NODE_MAJOR=20

# Install build dependencies
RUN apk add --no-cache \
    git \
    nodejs \
    npm \
    # PHP extension dependencies
    autoconf \
    g++ \
    make \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libxml2-dev \
    imagemagick-dev \
    imagemagick \
    oniguruma-dev \
    && rm -rf /var/cache/apk/*

# Install PHP extensions required by Antragsgruen
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
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
        mbstring \
        fileinfo \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /build

# Clone Antragsgruen repository
RUN git clone --depth 1 --branch ${ANTRAGSGRUEN_VERSION} \
    https://github.com/CatoTH/antragsgruen.git . \
    && rm -rf .git

# Install PHP dependencies
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --prefer-dist

# Install Node.js dependencies and build assets
RUN npm ci --production=false \
    && npm run build || npm run gulp || npx gulp \
    && rm -rf node_modules \
    && npm cache clean --force

# Create necessary directories and set permissions
RUN mkdir -p \
    runtime/backups \
    runtime/cache \
    runtime/logs \
    web/assets \
    config \
    && touch config/config.json \
    && chmod -R 777 runtime web/assets config

###############################################################################
# Runtime Stage: Lean production image
###############################################################################
FROM php:${PHP_VERSION}-fpm-alpine AS runtime

ARG ANTRAGSGRUEN_VERSION
LABEL org.opencontainers.image.title="Motion Tools - PHP-FPM" \
      org.opencontainers.image.description="PHP-FPM container for Antragsgruen (Motion Tools)" \
      org.opencontainers.image.version="${ANTRAGSGRUEN_VERSION}" \
      org.opencontainers.image.source="https://github.com/yourusername/motion-tools-container" \
      org.opencontainers.image.licenses="MIT"

# Install runtime dependencies only
RUN apk add --no-cache \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    icu \
    icu-data-full \
    libxml2 \
    imagemagick \
    imagemagick-libs \
    oniguruma \
    msmtp \
    ca-certificates \
    mysql-client \
    netcat-openbsd \
    gettext \
    su-exec \
    && rm -rf /var/cache/apk/*

# Install PHP extensions (copy from builder or install again)
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Install additional runtime PHP extensions if not copied
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
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
        mbstring \
        fileinfo 2>/dev/null || true

# Copy application from builder
COPY --from=builder --chown=www-data:www-data /build /var/www/html

# Copy PHP configuration templates
COPY php.ini.template /usr/local/etc/php/conf.d/zz-antragsgruen.ini.template
COPY php-fpm.conf.template /usr/local/etc/php-fpm.d/zz-antragsgruen.conf.template
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck
COPY msmtprc.template /etc/msmtprc.template

# Make scripts executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/php-fpm-healthcheck

# Create volumes for persistent data
VOLUME ["/var/www/html/runtime", "/var/www/html/web/assets", "/var/www/html/config"]

# Set working directory
WORKDIR /var/www/html

# Expose PHP-FPM port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD php-fpm-healthcheck || exit 1

# Use custom entrypoint (runs as root, drops to www-data)
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]

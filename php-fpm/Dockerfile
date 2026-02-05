# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.4
ARG ANTRAGSGRUEN_VERSION=v4.17-volt

FROM public.ecr.aws/docker/library/php:${PHP_VERSION}-fpm-alpine AS builder

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

COPY --from=public.ecr.aws/docker/library/composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /build

RUN git clone --depth 1 --branch ${ANTRAGSGRUEN_VERSION} \
    https://github.com/CatoTH/antragsgruen.git . \
    && rm -rf .git

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

FROM public.ecr.aws/docker/library/php:${PHP_VERSION}-fpm-alpine AS runtime

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
    fcgi

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=builder --chown=www-data:www-data /build /var/www/html

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

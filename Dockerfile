#syntax=docker/dockerfile:1.4

# Build arguments
ARG VERSION=0.1.0
ARG PHP_VERSION=8.2

# pin versions
FROM php:$PHP_VERSION-fpm-alpine as base

# OpenContainers Annotations
# ref: https://github.com/opencontainers/image-spec/blob/main/annotations.md
# created: date '+%Y-%m-%dT%H:%M:%SZ'
LABEL org.opencontainers.base.name="ghcr.io/fmjstudios/shopware:latest" \
      org.opencontainers.image.created="2024-09-24T09:21:15Z" \
      org.opencontainers.image.description="Shopware - packaged by FMJ Studios" \
      org.opencontainers.image.documentation="https://github.com/fmjstudios/shopware/wiki" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/fmjstudios/shopware" \
      org.opencontainers.image.source="https://github.com/fmjstudios/shopware" \
      org.opencontainers.image.title="shopware" \
      org.opencontainers.image.vendor="FMJ Studios" \
      org.opencontainers.image.authors="info@fmj.studio" \
      org.opencontainers.image.version=$VERSION

# container settings
ARG PUID=1001
ARG PGID=1001
ARG PORT=9161

# install `install-php-extensions` to install extensions (and composer) with all dependencies included
# install Shopware required PHP extensions and the latest version of Composer
# ref: https://github.com/mlocati/docker-php-extension-installer
# ref: https://developer.shopware.com/docs/guides/installation/requirements.html
RUN curl -sSLf \
        -o /usr/local/bin/install-php-extensions \
        https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions \
        @composer \
        bcmath \
        gd \
        intl \
        mysqli \
        pdo_mysql \
        pcntl \
        sockets \
        bz2 \
        gmp \
        soap \
        zip \
        ffi \
        redis \
        opcache \
        apcu \
        amqp \
        sodium \
        opentelemetry \
        grpc

# install OS dependencies
RUN apk add --no-cache \
    bash=~5.2 \
    nginx=~1.26 \
    supervisor=~4.2 \
    jq=~1.7 \
    trurl \
    envsubst

# define core environment variables (php-cli, php-fpm, utils.sh)
ENV PUID=${PUID} \
    PGID=${PGID} \
    PORT=${PORT} \
    DATABASE_TIMEOUT=120 \
    PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT" \
    PHP_DISPLAY_ERRORS=Off \
    PHP_MAX_UPLOAD_SIZE=32M \
    PHP_MAX_EXECUTION_TIME=60 \
    PHP_MEMORY_LIMIT=512M \
    PHP_SESSION_COOKIE_LIFETIME=0 \
    PHP_SESSION_GC_MAXLIFETIME=1440 \
    PHP_SESSION_HANDLER=files \
    PHP_SESSION_SAVE_PATH="" \
    PHP_OPCACHE_ENABLE_CLI=0 \
    PHP_OPCACHE_FILE_OVERRIDE=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=20 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=10000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_OPCACHE_FILE_CACHE="" \
    PHP_OPCACHE_FILE_CACHE_ONLY="0" \
    PHP_REALPATH_CACHE_TTL=4096k \
    PHP_REALPATH_CACHE_SIZE=3600 \
    PHP_FPM_PM=dynamic \
    PHP_FPM_MAX_CHILDREN=15 \
    PHP_FPM_START_SERVERS=5 \
    PHP_FPM_MIN_SPARE_SERVERS=2 \
    PHP_FPM_MAX_SPARE_SERVERS=5 \
    PHP_FPM_MAX_SPAWN_RATE=2 \
    PHP_FPM_PROCESS_IDLE_TIMEOUT=10s \
    PHP_FPM_MAX_REQUESTS=0 \
    PHP_FPM_STATUS_PATH="/-/fpm/status" \
    PHP_FPM_PING_PATH="/-/fpm/ping" \
    PHP_FPM_ACCESS_LOG="/proc/self/fd/2" \
    PHP_FPM_ERROR_LOG="/proc/self/fd/2" \
    PHP_FPM_LOG_LEVEL=notice \
    PHP_FPM_DAEMONIZE=no \
    PHP_FPM_RLIMIT_FILES=8192 \
    PHP_FPM_LOG_LIMIT=8192

# configure PHP
RUN rm -rf /usr/local/etc/php/php.ini*
COPY --chmod=644 docker/conf/php/php.ini /usr/local/etc/php
COPY --chmod=644 docker/conf/php/docker-php.ini /usr/local/etc/php/conf.d

# configure PHP-FPM
RUN rm -rf /usr/local/etc/php-fpm.d/* && \
    rm -rf /usr/local/etc/php-fpm.conf*

COPY --chmod=644 docker/conf/php-fpm/php-fpm.conf /usr/local/etc
COPY --chmod=644 docker/conf/php-fpm/www.conf /usr/local/etc/php-fpm.d

# configure Nginx
RUN rm -rf /etc/nginx/http.d/*.conf
COPY --chmod=644 docker/conf/nginx/nginx.conf /etc/nginx
COPY --chmod=644 docker/conf/nginx/shopware-http.conf /etc/nginx/http.d/shopware.conf

# configure Supervisor
RUN mkdir -p /etc/supervisor /etc/supervisor/conf.d
COPY --chmod=644 docker/conf/supervisor/supervisord.conf /etc/supervisor

# create and own directories required by services
RUN <<EOF
mkdir -p /var/log/nginx /var/log/php-fpm /var/log/supervisor /var/www/html /run/php
chmod -R 755 /run/php
chown -R 82:82 /var/log/nginx /var/lib/nginx /var/log/php-fpm /var/log/supervisor /var/www/html /run/php
EOF

FROM base as system

ARG PORT

# add container executables and library scripts
COPY --chmod=755 docker/bin/swctl /usr/local/bin
COPY --chmod=644 docker/lib/utils.sh /usr/local/lib/utils.sh

# add a healthcheck
# ref: https://developer.shopware.com/docs/guides/hosting/installation-updates/cluster-setup.html#health-check
HEALTHCHECK --start-period=3m --timeout=5s --interval=10s --retries=75 \
   CMD curl --fail "http://localhost:${PORT:-9161}/api/_info/health-check" || exit 1

# prepare image for volumes - has to be done before we copy sources
VOLUME [ "/var/www/html/files", "/var/www/html/public/theme", "/var/www/html/public/media", "/var/www/html/public/thumbnail", "/var/www/html/public/public" ]
# create and own directories required by volumes
RUN <<EOF
mkdir -p /var/www/html/files /var/www/html/public/theme /var/www/html/public/media /var/www/html/public/thumbnail /var/www/html/public/public
chown -R 82:82 /var/www/html/files /var/www/html/public/theme /var/www/html/public/media /var/www/html/public/thumbnail /var/www/html/public/public
EOF

# 'build' stage is analogous to 'dev'
FROM system as dev

# install shopware-cli
RUN apk add --no-cache bash && \
    curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.alpine.sh' | bash && \
    apk add --no-cache shopware-cli

# copy all (non-ignored) sources
WORKDIR /var/www/html
COPY --link --chown=82:82 . ./
RUN rm -rf ./docker # remove non-ignorable docker dir

# provide your own envs - we only set what's required
ENV APP_ENV=dev \
    LOCK_DSN=flock

RUN --mount=type=secret,id=composer_auth,dst=./auth.json \
    --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    shopware-cli project ci --with-dev-dependencies .

## just start the server
USER www-data

ENTRYPOINT ["swctl", "run"]

# build without dev deps
FROM dev as build

WORKDIR /app

# switch back to build
USER root

# prod build - provide your own envs
ENV APP_ENV=prod \
    LOCK_DSN=flock \
    APP_URL="https://shopware.internal" \
    APP_URL_CHECK_DISABLED=1 \
    DATABASE_URL=mysql://shopware:shopware@127.0.0.1:3306/shopware

RUN rm -rf /app/vendor # remove old (dev) dependencies
RUN --mount=type=secret,id=composer_auth,dst=/app/auth.json \
    --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    shopware-cli project ci /app

# final prod image
FROM system as prod

# set default Shopware environment variables
ENV APP_ENV=prod \
    APP_SECRET="" \
    APP_URL="https://shopware.internal" \
    APP_URL_CHECK_DISABLED=0 \
    INSTANCE_ID="" \
    LOCK_DSN=flock \
    MAILER_DSN=null://null \
    DATABASE_URL=mysql://shopware:shopware@mysql:3306/shopware \
    OPENSEARCH_URL="" \
    BLUE_GREEN_DEPLOYMENT=0 \
    SHOPWARE_ES_ENABLED=0 \
    SHOPWARE_ES_INDEXING_ENABLED=0 \
    SHOPWARE_ES_INDEX_PREFIX="sw" \
    SHOPWARE_ES_THROW_EXCEPTION="1" \
    SHOPWARE_HTTP_CACHE_ENABLED=1 \
    SHOPWARE_HTTP_DEFAULT_TTL=7200 \
    SHOPWARE_CACHE_ID=docker \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    COMPOSER_PLUGIN_LOADER=1 \
    COMPOSER_HOME="/tmp/composer" \
    OTEL_PHP_AUTOLOAD_ENABLED=false \
    OTEL_PHP_DISABLED_INSTRUMENTATIONS=shopware \
    OTEL_SERVICE_NAME=shopware \
    OTEL_TRACES_EXPORTER=otlp \
    OTEL_LOGS_EXPORTER=otlp \
    OTEL_METRICS_EXPORTER=otlp \
    OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
    OTEL_EXPORTER_OTLP_ENDPOINT=https://opentelemetry-exporter:4317 \
    INSTALL_LOCALE="en-GB" \
    INSTALL_CURRENCY=EUR \
    INSTALL_ADMIN_USERNAME=admin \
    INSTALL_ADMIN_PASSWORD=shopware

# doc-root
WORKDIR /var/www/html

# perms
RUN chown -R 82:82 .
COPY --from=build --chown=82:82 /app ./

# uid/gid 82
USER www-data
ENTRYPOINT ["swctl", "run"]

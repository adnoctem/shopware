#syntax=docker/dockerfile:1.4

# select a valid PHP version
ARG PHP_VERSION=8.2

# pin versions
FROM php:$PHP_VERSION-fpm-alpine as base

# container settings
ARG PHP_VERSION=8.2
ARG PUID=1001
ARG PGID=1001
ARG PORT=8080
ARG HOSTNAME=localhost

# OpenContainers Annotations
# ref: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Shopware 6"
LABEL org.opencontainers.image.description="Shopware 6 is an open source headless commerce platform powered by Symfony 7 and Vue.js 3."
LABEL org.opencontainers.image.authors="info@fmj.studio"
LABEL org.opencontainers.image.url="ghcr.io/fmjstudios/shopware"
LABEL org.opencontainers.image.documentation="https://github.com/fmjstudios/shopware/wiki"
LABEL org.opencontainers.image.source="https://github.com/fmjstudios/shopware"

FROM base as init

# install `install-php-extensions` to install extensions (and composer) with all dependencies included
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/


# install Shopware 6 required PHP extensions and the latest version of Composer
# ref: https://github.com/mlocati/docker-php-extension-installer
# ref: https://developer.shopware.com/docs/guides/installation/requirements.html
RUN install-php-extensions gd intl xdebug mysqli pdo_mysql pcntl sockets bz2 gmp soap zip zlib ffi redis opcache apcu amqp sodium @composer

# install system dependencies
RUN apk add --no-cache nginx supervisor jq trurl envsubst

# define core environment variables (php-cli, php-fpm, entrypoint, utils.sh)
ENV PUID=$PUID \
    PGID=$PGID \
    PORT=$PORT \
    HOSTNAME=$HOSTNAME \
    DATABASE_TIMEOUT=120 \
    PHP_ERROR_REPORTING=E_ALL \
    PHP_DISPLAY_ERRORS=Off \
    PHP_MAX_UPLOAD_SIZE=128m \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_MEMORY_LIMIT=512m \
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
    PHP_FPM_MAX_CHILDREN=5 \
    PHP_FPM_START_SERVERS=2 \
    PHP_FPM_MIN_SPARE_SERVERS=1 \
    PHP_FPM_MAX_SPARE_SERVERS=3 \
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

# crate user and group
RUN <<EOF
addgroup --system --gid ${PUID} shopware
adduser --system --uid ${PGID} shopware
EOF

# remove default configuration files & create default configuration locations
RUN <<EOF
rm -rf /usr/local/etc/php-fpm.d/*
rm -rf /usr/local/etc/php-fpm.conf*
rm -rf /usr/local/etc/php/php.ini*
mkdir -p /var/www/html
mkdir -p /usr/local/etc/nginx/templates
mkdir -p /usr/local/etc/supervisor
EOF

# config files
COPY --chown=${PUID}:${PGID} docker/conf/php.ini /usr/local/etc/php
COPY --chown=${PUID}:${PGID} docker/conf/docker-php.ini /usr/local/etc/php/conf.d
COPY --chown=${PUID}:${PGID} docker/conf/php-fpm.conf /usr/local/etc
COPY --chown=${PUID}:${PGID} docker/conf/www.conf /usr/local/etc/php-fpm.d
COPY --chown=${PUID}:${PGID} docker/conf/supervisor.conf /usr/local/etc/supervisor
COPY --chown=${PUID}:${PGID} docker/conf/nginx.conf.template /usr/local/etc/nginx/templates/nginx.conf.template

# executables & libs
COPY --chown=${PUID}:${PGID} --chmod=755 docker/bin/swctl /usr/local/bin
COPY --chown=${PUID}:${PGID} --chmod=755 docker/lib/utils.sh /usr/local/lib
COPY --chown=0:0 --chmod=755 docker/entrypoint.sh /usr/sbin

# produce a valid first Nginx config & own files
RUN <<EOF
envsubst < /usr/local/etc/nginx/templates/nginx.conf.template > /usr/local/etc/nginx/nginx.conf
chown -R ${PUID}:${PGID} /var/www/html /usr/local/lib /usr/local/etc
EOF

# set Shopware environment variables
ENV APP_ENV=prod \
    APP_URL=${HOSTNAME} \
    APP_URL_CHECK_DISABLED=1 \
    INSTANCE_ID="" \
    LOCK_DSN=flock \
    MAILER_DSN=null://localhost \
    DATABASE_URL=mysql://root:root@mysql:3306/shopware \
    DATABASE_PORT=3306 \
    OPENSEARCH_URL="" \
    BLUE_GREEN_DEPLOYMENT=0 \
    SHOPWARE_ES_ENABLED=0 \
    SHOPWARE_ES_INDEXING_ENABLED=0 \
    SHOPWARE_ES_INDEX_PREFIX="sw" \
    SHOPWARE_ES_THROW_EXCEPTION="1" \
    MESSENGER_TRANSPORT_DSN="" \
    STOREFRONT_PROXY_URL="http://localhost" \
    SHOPWARE_HTTP_CACHE_ENABLED=1 \
    SHOPWARE_HTTP_DEFAULT_TTL=7200 \
    SHOPWARE_CACHE_ID=docker \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    COMPOSER_PLUGIN_LOADER=1 \
    COMPOSER_HOME="/tmp/composer" \
    INSTALL_LOCALE="en-GB" \
    INSTALL_CURRENCY=EUR \
    INSTALL_ADMIN_USERNAME=admin \
    INSTALL_ADMIN_PASSWORD=shopware

FROM ghcr.io/friendsofshopware/shopware-cli:latest-php-$PHP_VERSION as build

COPY --link . /app
WORKDIR /app

RUN --mount=type=secret,id=composer_auth,dst=/src/auth.json \
    --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    shopware-cli project ci /app

FROM init as final

COPY --from=build --chown=${PUID}:${PGID} /app /var/www/html
WORKDIR /var/www/html
USER ${PUID}
EXPOSE ${PORT}

ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
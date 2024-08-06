#syntax=docker/dockerfile:1.4

# select a valid PHP version
ARG PHP_VERSION=8.2

# pin versions
FROM php:$PHP_VERSION-fpm-alpine as base
FROM mlocati/php-extension-installer:2.2 as php-ext

# OpenContainers Annotations
# ref: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Shopware 6"
LABEL org.opencontainers.image.description="Shopware 6 is an open source headless commerce platform powered by Symfony 7 and Vue.js 3."
LABEL org.opencontainers.image.authors="info@fmj.studio"
LABEL org.opencontainers.image.url="ghcr.io/fmjstudios/shopware"
LABEL org.opencontainers.image.documentation="https://github.com/fmjstudios/shopware/wiki"
LABEL org.opencontainers.image.source="https://github.com/fmjstudios/shopware"

FROM base as init

# container settings
ARG PHP_VERSION
ARG PUID=1001
ARG PGID=1001
ARG PORT=9161

# install `install-php-extensions` to install extensions (and composer) with all dependencies included
COPY --from=php-ext /usr/bin/install-php-extensions /usr/local/bin/

# install Shopware 6 required PHP extensions and the latest version of Composer
# ref: https://github.com/mlocati/docker-php-extension-installer
# ref: https://developer.shopware.com/docs/guides/installation/requirements.html
RUN install-php-extensions gd intl xdebug mysqli pdo_mysql pcntl sockets bz2 gmp soap ffi redis opcache apcu amqp zip sodium @composer

# install system dependencies
RUN apk add --no-cache nginx supervisor jq trurl envsubst

# define core environment variables (php-cli, php-fpm, utils.sh)
ENV PUID=$PUID \
    PGID=$PGID \
    PORT=$PORT \
    DATABASE_TIMEOUT=120 \
    PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT" \
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
adduser --system --uid ${PUID} shopware
addgroup --system --gid ${PGID} shopware
EOF

# configure PHP
RUN rm -rf /usr/local/etc/php/php.ini*
COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/php/php.ini /usr/local/etc/php
COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/php/docker-php.ini /usr/local/etc/php/conf.d

# configure PHP-FPM
RUN rm -rf /usr/local/etc/php-fpm.d/* && \
    rm -rf /usr/local/etc/php-fpm.conf*

COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/php-fpm/php-fpm.conf /usr/local/etc
COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/php-fpm/www.conf /usr/local/etc/php-fpm.d

# configure Nginx
RUN rm -rf /etc/nginx/http.d/*.conf
COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/nginx/nginx.conf /etc/nginx
COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/nginx/shopware-http.conf /etc/nginx/http.d/shopware.conf

# configure Supervisor
RUN mkdir -p /etc/supervisor
COPY --chown=${PUID}:${PGID} --chmod=644 docker/conf/supervisor/supervisord.conf /etc/supervisor

# add container executables and library scripts
COPY --chown=${PUID}:${PGID} --chmod=755 docker/bin/swctl /usr/local/bin
COPY --chown=${PUID}:${PGID} --chmod=644 docker/lib/utils.sh /usr/local/lib

# create and own directories required by services
RUN <<EOF
mkdir -p /var/log/nginx /var/log/php-fpm /var/www/html /run/php
chown -R $PUID:$PGID /var/log/nginx /var/log/php-fpm /var/www/html /run/php
EOF

# set default Shopware environment variables
ENV APP_ENV=prod \
    APP_URL="http://localhost" \
    APP_URL_CHECK_DISABLED=1 \
    INSTANCE_ID="" \
    LOCK_DSN=flock \
    MAILER_DSN=null://null \
    DATABASE_URL=mysql://root:root@mysql:3306/shopware \
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
    INSTALL_LOCALE="en-GB" \
    INSTALL_CURRENCY=EUR \
    INSTALL_ADMIN_USERNAME=admin \
    INSTALL_ADMIN_PASSWORD=shopware

# initialize a clean build stage
FROM ghcr.io/friendsofshopware/shopware-cli:latest-php-$PHP_VERSION as build

# copy all files to to image and delete files which can't be ignored but aren't needed
COPY --link . /app
RUN rm -rf /app/docker /app/*compose.yaml
WORKDIR /app

# build assets & install dependencies
# ref: https://sw-cli.fos.gg/commands/project/#shopware-cli-project-ci
RUN --mount=type=secret,id=composer_auth,dst=/src/auth.json \
    --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    shopware-cli project ci /app

FROM init as final

ARG PUID
ARG PGID
ARG PORT

# add a healthcheck
# ref: https://developer.shopware.com/docs/guides/hosting/installation-updates/cluster-setup.html#health-check
HEALTHCHECK --start-period=3m --timeout=5s --interval=1m --retries=10 \
   CMD curl --fail "http://localhost:${PORT:-9161}/api/_info/health-check" || exit 1

COPY --from=build --chown=$PUID:$PGID --chmod=644 /app /var/www/html

VOLUME [ "/var/www/html/files", "/var/www/html/public/theme", "/var/www/html/public/media", "/var/www/html/public/thumbnail", "/var/www/html/public/public" ]

# create later mount locations for correct permissions
# ref: https://serverfault.com/a/984599
RUN <<EOF
mkdir -p /var/www/html/files /var/www/html/public/theme /var/www/html/public/media /var/www/html/public/thumbnail /var/www/html/public/sitemap
chown -R $PUID:$PGID /var/www/html/files /var/www/html/public/theme /var/www/html/public/media /var/www/html/public/thumbnail /var/www/html/public/sitemap
EOF

# produce a valid first Nginx config & own files
RUN find /var/www/html -type f -exec chmod 644 {} + && \
    find /var/www/html -type d -exec chmod 755 {} + && \
    chown -R $PUID:$PGID /var/www/html

WORKDIR /var/www/html

EXPOSE $PORT

ENTRYPOINT ["swctl", "run"]
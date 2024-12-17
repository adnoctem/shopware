# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.

ARG PHP_VERSION=8.3

FROM php:$PHP_VERSION-fpm-alpine AS php-base

# install `install-php-extensions` to install extensions (and composer) with all dependencies included
# install Shopware required PHP extensions and the latest version of Composer
# ref: https://github.com/mlocati/docker-php-extension-installer
# ref: https://developer.shopware.com/docs/guides/installation/requirements.html
RUN  --mount=type=bind,from=mlocati/php-extension-installer:latest,source=/usr/bin/install-php-extensions,target=/usr/local/bin/install-php-extensions \
    install-php-extensions \
        @composer \
        bcmath \
        gd \
        intl \
        mysqli \
        pdo_mysql \
        sockets \
        bz2 \
        zip \
        redis \
        opcache \
        apcu \
        sodium

# -------------------------------------
# PHP configuration
# -------------------------------------
FROM php-base AS php

ARG EXTRA_PHP_EXTENSIONS="opentelemetry grpc"

RUN  --mount=type=bind,from=mlocati/php-extension-installer:latest,source=/usr/bin/install-php-extensions,target=/usr/local/bin/install-php-extensions \
    install-php-extensions ${EXTRA_PHP_EXTENSIONS}

ARG PORT=9000

# define core environment variables (php-cli, php-fpm, utils.sh)
ENV PORT="${PORT}" \
    DATABASE_TIMEOUT=120 \
    OPENSEARCH_TIMEOUT=120 \
    REDIS_TIMEOUT=120 \
    PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT" \
    PHP_DISPLAY_ERRORS="Off" \
    PHP_MAX_UPLOAD_SIZE="32M" \
    PHP_MAX_EXECUTION_TIME=60 \
    PHP_MEMORY_LIMIT="512M" \
    PHP_SESSION_COOKIE_LIFETIME=0 \
    PHP_SESSION_GC_MAXLIFETIME=1440 \
    PHP_SESSION_HANDLER="files" \
    PHP_SESSION_SAVE_PATH="" \
    PHP_OPCACHE_ENABLE_CLI=0 \
    PHP_OPCACHE_FILE_OVERRIDE=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=20 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=10000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_OPCACHE_FILE_CACHE="" \
    PHP_OPCACHE_FILE_CACHE_ONLY=0 \
    PHP_REALPATH_CACHE_TTL="4096k" \
    PHP_REALPATH_CACHE_SIZE=3600 \
    PHP_FPM_PM="dynamic" \
    PHP_FPM_LISTEN="${PORT}" \
    PHP_FPM_MAX_CHILDREN=15 \
    PHP_FPM_START_SERVERS=5 \
    PHP_FPM_MIN_SPARE_SERVERS=2 \
    PHP_FPM_MAX_SPARE_SERVERS=5 \
    PHP_FPM_MAX_SPAWN_RATE=2 \
    PHP_FPM_PROCESS_IDLE_TIMEOUT=10s \
    PHP_FPM_MAX_REQUESTS=0 \
    PHP_FPM_STATUS_PATH="/-/fpm/status" \
    PHP_FPM_PING_PATH="/-/fpm/ping" \
    PHP_FPM_ACCESS_LOG="/proc/self/fd/1" \
    PHP_FPM_ERROR_LOG="/proc/self/fd/2" \
    PHP_FPM_LOG_LEVEL="notice" \
    PHP_FPM_DAEMONIZE="no" \
    PHP_FPM_RLIMIT_FILES=8192 \
    PHP_FPM_LOG_LIMIT=8192

# Remove default directories (or create required ones)
RUN rm -rf /usr/local/etc/php/php.ini* ; \
    rm -rf /usr/local/etc/php-fpm.d/* ; \
    rm -rf /usr/local/etc/php-fpm.conf* ; \
    mkdir -p /etc/supervisor/conf.d

# copy config files for PHP, PHP-FPM & Supervisor
COPY --chmod=644 docker/conf/php/php.ini /usr/local/etc/php
COPY --chmod=644 docker/conf/php/docker-php.ini /usr/local/etc/php/conf.d
COPY --chmod=644 docker/conf/php-fpm/php-fpm.conf /usr/local/etc
COPY --chmod=644 docker/conf/php-fpm/www.conf /usr/local/etc/php-fpm.d
COPY --chmod=644 docker/conf/supervisor/supervisord.conf /etc/supervisor

# -------------------------------------
# System + Environment configuration
# -------------------------------------
FROM php AS system

ARG PORT
ARG USER=shopware
ARG PUID=1001
ARG PGID=1001

# create (unprivileged) shopware user and create/own required directories
# NOTE: logs should be redirected to std streams
RUN \
    addgroup -g ${PGID} -S ${USER}; \
	adduser -D ${USER} -G ${USER} -u ${PUID} ; \
    mkdir -p -m 660 /var/www/html /run/php ; \
    chown -R ${PUID}:${PGID} /var/www/html /run/php

# configure Shell and install base dependencies
RUN apk update && apk add --no-cache \
    bash=~5.2 \
    supervisor=~4.2 \
    jq=~1.7 \
    busybox \
    fcgi \
    nodejs \
    npm \
    trurl \
    acl \
    shadow
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# ensure we source the new bashrc even if we're not in a login shell
# ref: https://stackoverflow.com/questions/38024160/how-to-get-etc-profile-to-run-automatically-in-alpine-docker
ENV ENV=${HOME}/.bashrc

# set doc-root
WORKDIR /var/www/html

# switch shells & ensure we source /etc/profile and our utils
RUN chsh -s /bin/bash shopware ; \
    chsh -s /bin/bash root ; \
    echo ". /etc/profile" >> /home/${USER}/.bashrc ; \
    echo ". /etc/profile" >> /root/.bashrc ; \
    echo ". /usr/local/lib/utils.sh" >> /home/${USER}/.bashrc ; \
    echo ". /usr/local/lib/utils.sh" >> /root/.bashrc ; \
    ln -s /dev/null /home/${USER}/.bash_history ; \
    ln -s /dev/null /home/${USER}/.ash_history ; \
    ln -s /dev/null /root/.bash_history ; \
    ln -s /dev/null /root/.ash_history ; \
    setfacl -PRd -m user:${USER}:rwx,group:${USER}:rw,other::r .

# Mitigate invalid credentials in Shopware's Flysystem adapter,
# pre-setting known AWS environment variables to lock credentials,
# for the underlying AWS PHP SDK.
#
# ref: https://github.com/thephpleague/flysystem/issues/1759
RUN echo -e "\n# DO NOT REMOVE - the AWS SDK requires these\n" >> /etc/profile ; \
    echo 'export AWS_ACCESS_KEY_ID=$SHOPWARE_S3_ACCESS_KEY' >> /etc/profile ; \
    echo 'export AWS_SECRET_ACCESS_KEY=$SHOPWARE_S3_SECRET_KEY' >> /etc/profile

# add container executables and library scripts
COPY --chmod=755 docker/bin/swctl /usr/local/bin
COPY --chmod=644 docker/lib/utils.sh /usr/local/lib/utils.sh

# switch to unprivileged user
USER ${PUID}:${PGID}

# NOTE: volumes have largely been deprecated as Shopware now relies on an S3 bucket for remote state
# VOLUME [ "/var/www/html/files", "/var/www/html/public/theme", "/var/www/html/public/media", "/var/www/html/public/thumbnail", "/var/www/html/public/public" ]

# add a healthcheck
# ref: https://maxchadwick.xyz/blog/getting-the-php-fpm-status-from-the-command-line
HEALTHCHECK --start-period=3m --timeout=10s --interval=15s --retries=25 \
   CMD cgi-fcgi -bind -connect ${PHP_FPM_LISTEN} | grep -q "Status" || exit 1

# execute 'swctl' by default + expose 9000
ENTRYPOINT ["swctl"]
EXPOSE ${PORT}

# -------------------------------------
# Base Shopware configuration
# -------------------------------------
FROM system AS base

ARG USER
ARG PUID
ARG PGID

# install Shopware-CLI
# ref: https://sw-cli.fos.gg/install/
USER root
RUN curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.alpine.sh' | bash ; \
    apk add --no-cache shopware-cli ; \
    npm config set cache "/tmp/npm" --global

# Define Shopware's default settings
ENV APP_ENV=dev \
    APP_SECRET="" \
    APP_URL="https://shopware.internal" \
    APP_URL_CHECK_DISABLED=1 \
    INSTANCE_ID="" \
    LOCK_DSN=flock \
    MAILER_DSN=null://null \
    DATABASE_URL="mysql://shopware:shopware@mysql:3306/shopware" \
    BLUE_GREEN_DEPLOYMENT=0 \
    # HTTP caching settings (disabled by default)
    SHOPWARE_HTTP_CACHE_ENABLED=0 \
    SHOPWARE_HTTP_DEFAULT_TTL=7200 \
    SHOPWARE_CACHE_ID=docker \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    STOREFRONT_PROXY_URL=${APP_URL:-"https://shopware.internal"} \
    # disable ElasticSearch/OpenSearch by default
    SHOPWARE_ES_ENABLED=0 \
    OPENSEARCH_URL="http://opensearch:9200" \
    SHOPWARE_ES_INDEXING_ENABLED=0 \
    SHOPWARE_ES_INDEX_PREFIX="sw" \
    SHOPWARE_ES_THROW_EXCEPTION=1 \
    # force the use of the Composer-based plugin loader
    # ref: https://developer.shopware.com/docs/guides/hosting/installation-updates/deployments/build-w-o-db.html#compiling-the-administration-without-database
    COMPOSER_PLUGIN_LOADER=1 \
    COMPOSER_HOME="/tmp/composer" \
    # disable OpenTelemetry by default
    OTEL_PHP_AUTOLOAD_ENABLED=false \
    OTEL_PHP_DISABLED_INSTRUMENTATIONS=shopware \
    OTEL_SERVICE_NAME=shopware \
    OTEL_TRACES_EXPORTER=otlp \
    OTEL_LOGS_EXPORTER=otlp \
    OTEL_METRICS_EXPORTER=otlp \
    OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
    OTEL_EXPORTER_OTLP_ENDPOINT="https://tempo:4317" \
    # S3 configuration
    S3_PUBLIC_BUCKET=shop-public \
    S3_PRIVATE_BUCKET=shop-private \
    S3_REGION=eu-north-1 \
    S3_ACCESS_KEY=CHANGEME \
    S3_SECRET_KEY=CHANGEME \
    S3_ENDPOINT="https://s3.eu-north-1.amazonaws.com" \
    S3_CDN_URL="https://shop.cdn.fmj.services" \
    S3_USE_PATH_STYLE_ENDPOINT="true" \
    # Redis overrides
    PHP_SESSION_HANDLER="redis" \
    PHP_SESSION_SAVE_PATH="tcp://redis:6379" \
    REDIS_URL="redis://redis:6379" \
    # build settings
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    DISABLE_ADMIN_COMPILATION_TYPECHECK=true \
    # deployment-helper - define defaults
    INSTALL_LOCALE=en-GB \
    INSTALL_CURRENCY=EUR \
    SALES_CHANNEL_URL=${APP_URL:-"https://shopware.internal"}

# (re)-switch to unprivileged user
USER ${PUID}:${PGID}

# -------------------------------------
# DEVELOPMENT Image
# -------------------------------------
FROM base AS dev

# (re)-instantiate ARGs
ARG PUID
ARG PGID

# copy all (non-ignored) sources
ADD --chown=${PUID}:${PGID} --chmod=740 . .
RUN --mount=type=secret,uid=${PUID},gid=${PGID},id=composer_auth,dst=./auth.json \
    --mount=type=cache,uid=${PUID},gid=${PGID},target=/tmp/composer \
    --mount=type=cache,uid=${PUID},gid=${PGID},target=/tmp/npm \
    shopware-cli project ci --with-dev-dependencies . ; \
    rm -rf ./docker ; \
    echo "$(date '+%d-%m-%Y_%T')" >> install.lock

# initialize and run Shopware
CMD ["run"]

# -------------------------------------
# PRODUCTION Image
# -------------------------------------
FROM base AS prod
# (re)-instantiate ARGs
ARG PUID
ARG PGID

# overwrite defaults
ENV APP_ENV=prod \
    SHOPWARE_HTTP_CACHE_ENABLED=1 \
    APP_URL_CHECK_DISABLED=1

# link files for production build
COPY --link --chown=${PUID}:${PGID} --chmod=740 . .
RUN --mount=type=secret,uid=${PUID},gid=${PGID},id=composer_auth,dst=./auth.json \
    --mount=type=cache,uid=${PUID},gid=${PGID},target=/tmp/composer \
    --mount=type=cache,uid=${PUID},gid=${PGID},target=/tmp/npm \
    # (required) S3 credentials
    --mount=type=secret,id=S3_PUBLIC_BUCKET,env=S3_PUBLIC_BUCKET \
    --mount=type=secret,id=S3_PRIVATE_BUCKET,env=S3_PRIVATE_BUCKET \
    --mount=type=secret,id=S3_REGION,env=S3_REGION \
    --mount=type=secret,id=S3_ACCESS_KEY,env=S3_ACCESS_KEY \
    --mount=type=secret,id=S3_SECRET_KEY,env=S3_SECRET_KEY \
    --mount=type=secret,id=S3_ENDPOINT,env=S3_ENDPOINT \
    --mount=type=secret,id=S3_CDN_URL,env=S3_CDN_URL \
    --mount=type=secret,id=S3_USE_PATH_STYLE_ENDPOINT,env=S3_USE_PATH_STYLE_ENDPOINT \
    # mitigate invalid S3 credentials
    --mount=type=secret,id=S3_ACCESS_KEY,env=AWS_ACCESS_KEY_ID \
    --mount=type=secret,id=S3_SECRET_KEY,env=AWS_SECRET_ACCESS_KEY \
    shopware-cli project ci . ; \
    rm -rf ./docker ; \
    echo "$(date '+%d-%m-%Y_%T')" >> install.lock

# initialize and run Shopware
CMD ["run"]

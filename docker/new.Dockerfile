# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.

# NOTE: large parts of this code are inspired by (or taken) from the official Docker Inc. Wordpress image
# ref: https://github.com/docker-library/wordpress

ARG PHP_VERSION=8.3
ARG NODE_VERSION=20

FROM node:$NODE_VERSION-bookworm AS node
FROM php:$PHP_VERSION-fpm AS base

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# install PHP \
# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libavif-dev \
		libfreetype6-dev \
		libicu-dev \
		libjpeg-dev \
		libpng-dev \
		libwebp-dev \
		libzip-dev \
        libbz2-dev \
        libsodium-dev \
        libzstd-dev \
        zlib1g-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-avif \
		--with-freetype \
		--with-jpeg \
		--with-webp \
	; \
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		intl \
		mysqli \
        pdo_mysql \
		zip \
        sockets \
        bz2 \
        sodium \
	; \
    \
# install community extensions
    EXTENSIONS=( \
      "apcu" \
      "redis" \
      "grpc" \
      "opentelemetry" \
    ) ; \
    for EXT in "${EXTENSIONS[@]}"; do \
        MAKEFLAGS="-j $(nproc)" pecl install --onlyreqdeps --force "${EXT}" ; \
        docker-php-ext-enable "${EXT}" ; \
    done ; \
    rm -rf /tmp/pear ; \
    \
# Zend extensions
    ZEND_EXTENSIONS=( \
      "opcache" \
    ) ; \
    for ZEXT in "${ZEND_EXTENSIONS[@]}"; do \
        docker-php-ext-enable "${ZEXT}" ; \
    done ; \
    \
# some misbehaving extensions end up outputting to stdout 🙈 (https://github.com/docker-library/wordpress/issues/669#issuecomment-993945967)
	out="$(php -r 'exit(0);')"; \
	[ -z "$out" ]; \
	err="$(php -r 'exit(0);' 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]; \
	\
	extDir="$(php -r 'echo ini_get("extension_dir");')"; \
	[ -d "$extDir" ]; \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$extDir"/*.so \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
	! { ldd "$extDir"/*.so | grep 'not found'; }; \
# check for output like "PHP Warning:  PHP Startup: Unable to load dynamic library 'foo' (tried: ...)
	err="$(php --version 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]; \
    \
# strip built shared-objects to decrease size
    find "$extDir" -name '*.so' -type f -exec strip --strip-all {} \;

# configure PHP and cleanup obsolete files
RUN set -eux; \
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"; \
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf; \
    rm -f /usr/local/etc/php-fpm.d/www.conf; \
    rm -f /usr/local/etc/php-fpm.d/www.conf.default

# set recommended PHP.ini settings
RUN set -eux; \
	{ \
		echo 'expose_php=Off'; \
        echo 'error_reporting=E_ALL & ~E_DEPRECATED & ~E_STRICT'; \
        echo 'display_errors=Off'; \
        echo 'display_startup_errors=Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
        echo 'html_errors = Off'; \
        echo 'upload_max_filesize=32M'; \
        echo 'post_max_size=32M'; \
        echo 'max_execution_time=120'; \
        echo 'memory_limit=512M'; \
	} > /usr/local/etc/php/conf.d/general.ini

# set recommended session PHP.ini settings
RUN set -eux; \
	{ \
		echo 'session.cookie_lifetime=0'; \
        echo 'session.save_handler=files'; \
        echo 'session.save_path='; \
        echo 'session.gc_probability=0'; \
        echo 'session.gc_maxlifetime=1440'; \
	} > /usr/local/etc/php/conf.d/session.ini

# set recommended OPCache PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	{ \
        echo 'opcache.enable_cli=0'; \
        echo 'opcache.enable_file_override=1'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'opcache.interned_strings_buffer=20'; \
        echo 'opcache.file_cache='; \
        echo 'opcache.file_cache_only=0'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'zend.assertions=-1'; \
        echo 'zend.detect_unicode=0'; \
	} > /usr/local/etc/php/conf.d/opcache.ini

# set recommended realpath PHP.ini settings
RUN set -eux; \
	{ \
		echo 'realpath_cache_ttl=4096k'; \
        echo 'realpath_cache_size=3600'; \
	} > /usr/local/etc/php/conf.d/realpath.ini

# set recommended PHP-FPM settings
RUN set -eux; \
	{ \
        echo '[global]'; \
        echo 'daemonize=no'; \
        echo 'error_log=/proc/self/fd/2'; \
      # see: https://github.com/docker-library/php/pull/725#issuecomment-443540114
        echo 'log_limit = 8192'; \
        echo '[www]'; \
        echo 'listen=/run/php/php-fpm.sock'; \
        echo 'listen.mode=0660'; \
        echo 'pm=dynamic'; \
        echo 'pm.max_children=15'; \
        echo 'pm.start_servers=5'; \
        echo 'pm.min_spare_servers=2'; \
        echo 'pm.max_spare_servers=5'; \
        echo 'pm.max_spawn_rate=2'; \
        echo 'pm.process_idle_timeout=10s'; \
        echo 'pm.max_requests=0'; \
        echo 'pm.status_path=/-/fpm/status'; \
        echo 'ping.path=/-/fpm/ping'; \
        echo 'access.log=/dev/null'; \
        echo 'rlimit_files=8192'; \
        echo 'catch_workers_output=yes'; \
        echo 'decorate_workers_output=no'; \
        echo 'clear_env=no'; \
        echo 'php_admin_flag[log_errors]=on'; \
	} > /usr/local/etc/php-fpm.d/docker.conf

# install composer
RUN set -eux; \
    old_wd=$(pwd) && cd /tmp; \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"; \
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"; \
    php composer-setup.php; \
    php -r "unlink('composer-setup.php');"; \
    mv composer.phar /usr/local/bin/composer

# install Node.js and NPM at the given version
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/bin /usr/local/bin

WORKDIR /var/www/html

ENV COMPOSER_HOME=/tmp/composer \
    COMPOSER_CACHE_DIR=/tmp/composer/cache \
    COMPOSER_ALLOW_SUPERUSER=1 \
    npm_config_cache=/tmp/npm/cache \
    # set required defaults for a Shopware build
    APP_ENV=prod \
    APP_URL_CHECK_DISABLED=1

FROM base AS builder

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl; \
    mkdir -p /tmp/lib && cd /lib; \
    ldd /usr/local/bin/php | grep '=> /lib/' | cut -d' ' -f3 | sed 's#/lib/##g' | xargs -I % cp --parents "%" /tmp/lib; \
    ldd /usr/local/sbin/php-fpm | grep '=> /lib/' | cut -d' ' -f3 | sed 's#/lib/##g' | xargs -I % cp --parents "%" /tmp/lib

# install Shopware-CLI
# ref: https://sw-cli.fos.gg/install/
RUN curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.deb.sh' | bash ; \
    apt-get install -y --no-install-recommends shopware-cli

#FROM builder AS devbuild
#
#ADD --chmod=740 . .
#RUN --mount=type=cache,target=/tmp/composer/cache \
#    --mount=type=cache,target=/tmp/npm/cache \
#    shopware-cli project ci --with-dev-dependencies . ; \
#    rm -rf ./docker ; \
#    echo "$(date '+%d-%m-%Y_%T')" >> install.lock
#
#FROM builder AS prodbuild

#ENV APP_ENV=prod

# link files for production build
COPY --link --chmod=740 . .
RUN --mount=type=cache,target=/tmp/composer/cache \
    --mount=type=cache,target=/tmp/npm/cache \
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

FROM debian:bookworm-slim AS final

ENV PHP_INI_DIR=/usr/local/etc/php

# persistent dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
      ca-certificates \
      jq \
      libfcgi-bin \
	; \
	rm -rf /var/lib/apt/lists/*

# manual install of 'trurl'
RUN set -eux; \
    apt-get update; \
	  apt-get install -y --no-install-recommends \
        curl \
		libcurl4-openssl-dev \
    ; \
    # manual build
    old_wd=$(pwd) ; \
    cd /tmp ; \
    curl -fLO https://github.com/curl/trurl/releases/download/trurl-0.16/trurl-0.16.tar.gz ; \
    tar --extract --file trurl-0.16.tar.gz ; \
    cd trurl-0.16 ; \
    make && make install ; \
    cd "$old_wd" && rm -rf /tmp/trurl*; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ; \
      rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
WORKDIR /var/www/html

# add a healthcheck
# ref: https://maxchadwick.xyz/blog/getting-the-php-fpm-status-from-the-command-line
HEALTHCHECK --start-period=3m --timeout=10s --interval=15s --retries=25 \
   CMD cgi-fcgi -bind -connect /run/php/php-fpm.sock | grep -q "Status" || exit 1

COPY --from=builder /tmp/lib /lib
COPY --from=base /usr/local/lib/php /usr/local/lib/node* /usr/local/lib/
COPY --from=base /usr/local/bin/php /usr/local/bin/node /usr/local/bin/
COPY --from=base /usr/local/sbin/php* /usr/local/sbin/
COPY --from=base /usr/local/etc /usr/local/etc/

# configure the image and required directories
RUN set -eux; \
    mkdir -p /run/php /opt/adnoctem; \
    chmod g+rwX /opt/adnoctem; \
    PATH="/opt/adnoctem/bin:$PATH"

COPY --chmod=644 docker/lib /opt/adnoctem/lib/
COPY --chmod=644 docker/bin /opt/adnoctem/bin/

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm", "-F"]

FROM final AS dev

COPY --from=builder /var/www/html/. .
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
USER 1001

FROM final AS prod

COPY --from=builder /var/www/html/. .
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
USER 1001

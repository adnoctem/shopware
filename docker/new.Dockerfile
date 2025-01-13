# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.

ARG PHP_VERSION=8.3
ARG NODE_VERSION=22

FROM node:$NODE_VERSION-bookworm AS node
FROM php:$PHP_VERSION-fpm AS builder

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# persistent dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# jq is required for our Shopware shell utilities
		jq \
        libfcgi-bin \
	; \
	rm -rf /var/lib/apt/lists/*

# manual install of 'trurl'
RUN set -eux; \
    apt-get update; \
	apt-get install -y --no-install-recommends \
    # Require to build 'trurl'
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
        pecl install --onlyreqdeps --force "${EXT}" ; \
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
# strip built shared-objects
    for SO in "$extDir"/*.so; do \
        strip --strip-debug "$SO"; \
    done


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

# install Node.js at the given version
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

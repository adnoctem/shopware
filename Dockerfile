# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.

# NOTE: large parts of this code are inspired by (or taken) from the official Docker Inc. Wordpress image
# ref: https://github.com/docker-library/wordpress

ARG PHP_VERSION=8.3
ARG NODE_VERSION=20.18.2
# use --with-dev-dependencies for development (see docker-bake.hcl)
ARG BUILD_CMD="shopware-cli project ci ."
ARG APP_ENV=prod

FROM php:$PHP_VERSION-fpm-bookworm AS base

ARG NODE_VERSION
ARG APP_ENV
USER root

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
VOLUME ["/var/www/html"]
WORKDIR /var/www/html

# install PHP \
# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
	savedAptMark="$(apt-mark showmanual)"; \
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
    librabbitmq-dev \
    libssh-dev \
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
      "amqp" \
      "zstd" \
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
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
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

RUN set -eux; \
    # (re)move files & create directories
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"; \
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf; \
    rm -f /usr/local/etc/php-fpm.d/www.conf; \
    rm -f /usr/local/etc/php-fpm.d/www.conf.default; \
    mkdir -m 755 -p /opt/adnoctem/bin /opt/adnoctem/lib /opt/adnoctem/conf; \
    mkdir -m 775 -p /run/php && chmod 755 /var/www/html; \
    \
    # configure general PHP settings
    # see: https://developer.shopware.com/docs/guides/installation/requirements.html
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
	} > /usr/local/etc/php/conf.d/general.ini ; \
    \
  # set recommended session PHP.ini settings
	{ \
		echo 'session.cookie_lifetime=0'; \
    echo 'session.save_handler=files'; \
    echo 'session.save_path='; \
    echo 'session.gc_probability=0'; \
    echo 'session.gc_maxlifetime=1440'; \
	} > /usr/local/etc/php/conf.d/session.ini ; \
    \
  # set recommended OPCache PHP.ini settings
  # see https://secure.php.net/manual/en/opcache.installation.php
  # and https://developer.shopware.com/docs/guides/hosting/performance/performance-tweaks.html#php-config-tweaks
	{ \
    echo 'opcache.enable_cli=0'; \
    echo 'opcache.enable_file_override=1'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.interned_strings_buffer=20'; \
    echo 'opcache.file_cache='; \
    echo 'opcache.file_cache_only=0'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.max_accelerated_files=25000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'zend.assertions=-1'; \
    echo 'zend.detect_unicode=0'; \
	} > /usr/local/etc/php/conf.d/opcache.ini ; \
    \
  # set recommended realpath PHP.ini settings
	{ \
		echo 'realpath_cache_ttl=3600'; \
    echo 'realpath_cache_size=4096k'; \
	} > /usr/local/etc/php/conf.d/realpath.ini ; \
    \
  # set recommended PHP-FPM settings
	{ \
    echo '[global]'; \
    echo 'daemonize=no'; \
    echo 'error_log=/proc/self/fd/2'; \
  # see: https://github.com/docker-library/php/pull/725#issuecomment-443540114
    echo 'log_limit = 8192'; \
    echo '[www]'; \
    echo 'user=1001'; \
    echo 'group=1001'; \
    echo 'listen=/run/php/php-fpm.sock'; \
    echo 'listen.mode=0666'; \
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

# install Node.js, Composer, jq, socat and Shopware-CLI
RUN set -eux; \
    apt-get update; \
	  apt-get install -y --no-install-recommends  \
      netcat-openbsd curl libcurl4-openssl-dev; \
    # Shopware CLI - see: https://sw-cli.fos.gg/install/
    curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.deb.sh' | bash; \
    apt-get install -y --no-install-recommends shopware-cli; \
    cd /tmp ; \
    # Node + npm/npx - see: https://nodejs.org/dist/
    curl -fLO https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz; \
    tar -f node-v$NODE_VERSION-linux-x64.tar.gz -zx --exclude="*.md" --exclude="LICENSE" --exclude="include"  --exclude="share"  -C /usr/local --strip-components 1;\
    cd /tmp; \
    # static trurl binary - see: https://jqlang.github.io/jq/download/
    curl -fLO https://github.com/curl/trurl/releases/download/trurl-0.16/trurl-0.16.tar.gz ; \
    tar --extract --file trurl-0.16.tar.gz ; \
    cd trurl-0.16 ; \
    make && make install ; \
    cd /tmp; \
    # static socat binary - see: https://github.com/ernw/static-toolbox
    curl -fLO https://github.com/ernw/static-toolbox/releases/download/socat-v1.7.4.4/socat-1.7.4.4-x86_64 ; \
    chmod +x socat-1.7.4.4-x86_64 ; \
    mv socat-1.7.4.4-x86_64 /usr/local/bin/socat ; \
    # static jq binary - see: https://jqlang.github.io/jq/download/ \
    curl -fLO https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64 ; \
    chmod +x jq-linux-amd64 ; \
    mv jq-linux-amd64 /usr/local/bin/jq ; \
    cd /tmp; \
    # install composer - see: \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"; \
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"; \
    php composer-setup.php; \
    php -r "unlink('composer-setup.php');"; \
    mv composer.phar /usr/local/bin/composer; \
    cd /tmp; \
    # remove installation-dependencies
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false curl libcurl4-openssl-dev; \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/apt/archives

ENV PATH="/opt/adnoctem/bin:/usr/local/bin:/usr/local/sbin:$PATH" \
    COMPOSER_HOME=/tmp/composer \
    COMPOSER_CACHE_DIR=/tmp/composer/cache \
    COMPOSER_ALLOW_SUPERUSER=1 \
    npm_config_cache=/tmp/npm/cache \
    # force the use of the Composer-based plugin loader
    # ref: https://developer.shopware.com/docs/guides/hosting/installation-updates/deployments/build-w-o-db.html#compiling-the-administration-without-database
    COMPOSER_PLUGIN_LOADER=1 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    DISABLE_ADMIN_COMPILATION_TYPECHECK=true \
    # required (default) Shopware settings
    APP_ENV=$APP_ENV \
    LOCK_DSN="flock"

FROM base AS builder

ARG BUILD_CMD

# link files for build
COPY --link --chown=1001 --chmod=750 . .
RUN --mount=type=cache,target=/tmp/composer/cache \
    --mount=type=cache,target=/tmp/npm/cache \
    --mount=type=secret,id=composer_auth,target=./auth.json \
    # DSNs/URLs \
    --mount=type=secret,id=DATABASE_URL,env=DATABASE_URL \
    --mount=type=secret,id=OPENSEARCH_URL,env=OPENSEARCH_URL \
    --mount=type=secret,id=REDIS_URL,env=REDIS_URL \
    --mount=type=secret,id=MESSENGER_TRANSPORT_DSN,env=MESSENGER_TRANSPORT_DSN \
    --mount=type=secret,id=MAILER_DSN,env=MAILER_DSN \
    --mount=type=secret,id=LOCK_DSN,env=LOCK_DSN \
    # S3
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
    $BUILD_CMD ; \
    rm -rf ./docker ; \
    echo "$(date '+%d-%m-%Y_%T')" >> install.lock

COPY --chmod=755 docker/lib/lib*.sh /opt/adnoctem/lib
COPY --chmod=755 docker/conf/*.sh /opt/adnoctem/conf
COPY --chmod=755 docker/bin/entrypoint.sh /opt/adnoctem/bin

RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true ; \
    chmod g+rwX -R /var/www/html

# ref: https://unix.stackexchange.com/questions/556748/how-to-check-whether-a-socket-is-listening-or-not
HEALTHCHECK --start-period=120s --timeout=5s --interval=15s --retries=10 \
   CMD socat -u OPEN:/dev/null UNIX-CONNECT:/run/php/php-fpm.sock || exit 1

# -------------------------------------
# Final Image
# -------------------------------------
FROM builder AS final

# cleanup
RUN set -eux; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    # remove obsolete packages
    \
    PACKAGES=( \
      "gcc" \
      "gcc-12" \
      "g++" \
      "autoconf" \
      "binutils" \
      "pkg-config" \
      "pkgconf" \
      "make" \
      "shopware-cli" \
      #"perl" \
      "gpg" \
      # "sed" \
      #"xz-utils" \
      "grep" \
      #"gzip" \
    ) ; \
    for PKG in "${PACKAGES[@]}"; do \
        apt-get purge -y --auto-remove --allow-remove-essential "${PKG}" ; \
    done ; \
    # remove obsolete binaries and files
    \
    LOCATIONS=( \
      /usr/local/bin/composer \
      /usr/local/bin/corepack \
      /usr/local/bin/np* \
      /usr/local/bin/docker-php-* \
      /usr/local/bin/pear* \
      /usr/local/bin/pecl \
      /usr/local/bin/phar* \
      /usr/local/bin/phpize \
      /usr/local/bin/php-config \
      /usr/local/php \
      /usr/local/lib/node_modules \
    ) ; \
    for LOC in "${LOCATIONS[@]}"; do \
      rm -rf ${LOC} ; \
    done ; \
    find /usr/local/lib/php/ -mindepth 1 -maxdepth 1 ! -name extensions -exec rm -rf {} \; ;\
    # final cleanup
    \
    apt-get clean -y ; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives;

USER 1001

SHELL ["/bin/bash", "-c"]
STOPSIGNAL SIGQUIT

ENTRYPOINT ["entrypoint.sh"]
CMD ["-F"]

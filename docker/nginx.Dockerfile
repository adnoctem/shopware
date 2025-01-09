# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.
ARG VERSION=latest

# lock versions
FROM fmjstudios/shopware:${VERSION} AS base

# optionally inject build context via `buildx bake`
FROM base AS system

# (re)set args
ARG PORT=8000
ARG PUID=1001
ARG PGID=1001

# switch to root to modify the image
USER root

# install base dependencies
RUN apk add --no-cache \
    nginx=~1.26 \
    envsubst \
    supervisor

# configuration
RUN \
    rm -rf /etc/nginx/http.d/*.conf ; \
    mkdir -p -m 755 /var/log/supervisor ; \
    chown -R ${PUID}:${PGID} /var/www/html /var/log/supervisor /run/php

COPY --chmod=644 docker/conf/nginx/nginx.conf /etc/nginx
COPY --chmod=644 docker/conf/nginx/shopware-http.conf /etc/nginx/http.d/shopware.conf
COPY --chmod=644 docker/conf/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY --chmod=644 docker/conf/supervisor/nginx-supervisor.conf /etc/supervisor/conf.d/nginx.conf

# override FPM TCP listener to use a local socket
ENV PORT=${PORT:-8000} \
    PHP_FPM_LISTEN="/run/php/php-fpm.sock"

# override the default healthcheck
# ref: https://developer.shopware.com/docs/guides/hosting/installation-updates/cluster-setup.html#health-check
HEALTHCHECK --start-period=3m --timeout=5s --interval=10s --retries=75 \
   CMD curl --fail "http://localhost:${PORT:-8000}/api/_info/health-check" || exit 1

# (re)-switch to unprivileged user
USER ${PUID}:${PGID}

CMD ["run"]
EXPOSE ${PORT}

#syntax=docker/dockerfile:1.4

ARG VERSION=0.1.0
ARG PORT=8000
ARG USER=shopware

# lock versions
FROM fmjstudios/shopware:v${VERSION} as base
FROM base as system

# (re)set args
ARG USER
ARG PORT

# switch to root to modify the image
USER root

# install base dependencies
RUN apk add --no-cache \
    nginx=~1.26 \
    envsubst

# configuration
RUN rm -rf /etc/nginx/http.d/*.conf
COPY --chmod=644 docker/conf/nginx/nginx.conf /etc/nginx
COPY --chmod=644 docker/conf/nginx/shopware-http.conf /etc/nginx/http.d/shopware.conf
COPY --chmod=644 docker/conf/supervisor/nginx-supervised.conf /etc/supervisor/conf.d/nginx.conf

# create and own required directories
RUN <<EOF
mkdir -p /var/log/nginx
chmod -R 755 /run/php
chown -R ${USER}:${USER} /var/log/nginx /var/lib/nginx
EOF

# override FPM TCP listener to use a local socket
ENV PORT=${PORT:-8000} \
    PHP_FPM_LISTEN="/run/php/php-fpm.sock"

# add a healthcheck
# ref: https://developer.shopware.com/docs/guides/hosting/installation-updates/cluster-setup.html#health-check
HEALTHCHECK --start-period=3m --timeout=5s --interval=10s --retries=75 \
   CMD curl --fail "http://localhost:${PORT:-8000}/api/_info/health-check" || exit 1

# execute 'swctl' by default
ENTRYPOINT ["swctl"]

# -------------------------------------
# PRODUCTION Image
# -------------------------------------
FROM system as prod

# (re)set args
ARG PORT
ARG USER

# switch to unprivileged user
USER ${USER}
CMD ["run"]
EXPOSE ${PORT}

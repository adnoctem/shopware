#syntax=docker/dockerfile:1.4

FROM base as system

ARG USER=shopware
ARG PORT=8000

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

ENV PHP_FPM_LISTEN="/run/php/php-fpm.sock"

# switch to unprivileged user
USER ${USER}

# execute 'swctl' by default
ENTRYPOINT ["swctl"]

# -------------------------------------
# PRODUCTION Image
# -------------------------------------
FROM system as prod

CMD ["run"]

EXPOSE ${PORT}

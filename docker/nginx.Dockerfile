# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.
ARG NGINX_TAG=1.27

# lock versions
FROM nginx:${NGINX_TAG} AS base

ARG PORT

# configuration
RUN rm -rf /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf; \
    mkdir -p -m 755 /run/php; \
    chmod g+rwX /run/php

VOLUME ["/run/php"]

COPY --chmod=644 docker/conf/nginx/nginx.conf /etc/nginx
COPY --chmod=644 docker/conf/nginx/shopware-http.conf /etc/nginx/conf.d/shopware.conf

RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

EXPOSE 8000
USER 1001

CMD ["nginx", "-g", "daemon off;"]

#syntax=docker/dockerfile:1.4

# pin versions
FROM ghcr.io/shopware/docker-base:8.2 as base
FROM ghcr.io/friendsofshopware/shopware-cli:latest-php-8.2 as shopware-cli

# OpenContainers Annotations
# ref: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Shopware 6"
LABEL org.opencontainers.image.description="Shopware 6 is an open source headless commerce platform powered by Symfony 7 and Vue.js 3."
LABEL org.opencontainers.image.authors="info@fmj.studio"
LABEL org.opencontainers.image.url="ghcr.io/fmjstudios/shopware"
LABEL org.opencontainers.image.documentation="https://github.com/fmjstudios/shopware/wiki"
LABEL org.opencontainers.image.source="https://github.com/fmjstudios/shopware"

FROM shopware-cli as build

COPY --link .. /app
WORKDIR /app

RUN --mount=type=secret,id=composer_auth,dst=/src/auth.json \
    --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    /usr/local/bin/entrypoint.sh shopware-cli project ci /app

FROM base as final

COPY --from=build --chown=www-data /app /var/www/html

EXPOSE 8000
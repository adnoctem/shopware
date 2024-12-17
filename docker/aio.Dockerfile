# syntax=docker/dockerfile:1.12.0
#
# ref: https://docs.docker.com/build/buildkit/dockerfile-release-notes/
# Set the Docker syntax version. Limit features to release from 27-11-2024.
ARG VERSION=latest

# lock versions
FROM fmjstudios/shopware:${VERSION} AS base

# optionally inject build context via `buildx bake`
FROM base AS system

ARG PUID=1001
ARG PGID=1001

# configuration
COPY --chmod=644 docker/conf/supervisor/workers-supervisor.conf /etc/supervisor/conf.d/workers.conf

# (re)-switch to unprivileged user
USER ${PUID}:${PGID}

CMD ["run"]

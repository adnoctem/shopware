#!/usr/bin/env sh

# Get the PUID and PGID from environment variables (or use default values 1000 if not set)
export PUID="${PUID:-1001}"
export PGID="${PGID:-1001}"

chown -R "${PUID}:${PGID}" .

swctl run
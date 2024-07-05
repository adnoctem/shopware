#!/usr/bin/env sh

# Get the PUID and PGID from environment variables (or use default values 1000 if not set)
puid="${PUID:-1001}"
pgid="${PGID:-1001}"

# regenerate the nginx configuration of environment variables have changed from defaults
# shellcheck disable=SC2016
envsubst '\$PORT \$HOSTNAME' < /usr/local/etc/nginx/templates/nginx.conf.template > /usr/local/etc/nginx/nginx.conf

# (re-) own all files
chown -R "${puid}:${pgid}" .
chown -R "${puid}:${pgid}" /usr/local/lib
chown -R "${puid}:${pgid}" /usr/local/etc

su "${puid}"

swctl run
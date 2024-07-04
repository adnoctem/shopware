#!/usr/bin/env sh

# Get the PUID and PGID from environment variables (or use default values 1000 if not set)
puid="${PUID:-1001}"
pgid="${PGID:-1001}"

# regenerate the nginx configuration of environment variables have changed from defaults
envsubst < /usr/local/etc/nginx/templates/nginx.conf.template > /usr/local/etc/nginx/nginx.conf

# (re-) own all files
chown -R "${puid}:${pgid}" .

swctl run
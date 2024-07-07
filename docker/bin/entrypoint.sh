#!/usr/bin/env sh

# Get the PUID and PGID from environment variables (or use default values 1000 if not set)
puid="${PUID:-1001}"
pgid="${PGID:-1001}"

# regenerate the nginx configuration of environment variables have changed from defaults
# shellcheck disable=SC2016
#envsubst '\$PORT \$HOSTNAME' < /usr/local/etc/nginx/templates/shopware-http.conf.template > /usr/local/etc/nginx/conf.d/shopware-http.conf

# (re-) own all files
chown -R "${puid}:${pgid}" .

# (re-) set permissions
find /var/www/html -type f -exec chmod 644 {} +
find /var/www/html -type d -exec chmod 755 {} +

swctl run
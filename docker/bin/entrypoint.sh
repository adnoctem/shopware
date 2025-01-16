#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load Libraries
. /opt/adnoctem/lib/libadnoctem.sh
. /opt/adnoctem/lib/liblog.sh
. /opt/adnoctem/lib/libcheck.sh
. /opt/adnoctem/lib/libshopware.sh

print_banner

installed=$(is_shopware_installed)

# validate the various connections are available
database_connection_check
opensearch_connection_check
redis_connection_check

# if we're trying to run PHP-FPM for Shopware, check if it's even installed
if [[ $1 == "php-fpm" ]]; then
  if [[ "$installed" -ne 0 ]]; then
    log::yellow "Shopware was not found to be installed. Running initial installation"
    shopware_install
  else
    log::yellow "Shopware is installed. Running deployment helper to sync installation"
    run_deployment_helper
  fi
elif [[ $1 == "message-worker" ]]; then
  run_message_worker
elif [[ $1 == "cron-worker" ]]; then
  run_cron_worker
fi

exec "$@"

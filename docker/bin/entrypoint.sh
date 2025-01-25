#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o pipefail
# Uncomment this line for debugging purposes
# set -o xtrace

# Load Libraries
. /opt/adnoctem/lib/libadnoctem.sh
. /opt/adnoctem/lib/liblog.sh
. /opt/adnoctem/lib/libcheck.sh
. /opt/adnoctem/lib/libshopware.sh

# Load env
. /opt/adnoctem/conf/env.sh

print_banner

# MySQL/MariaDB
if [[ -n "${DATABASE_URL}" ]]; then
  database_connection_check
fi

# OpenSearch
if [[ -n "${OPENSEARCH_URL}" ]]; then
  opensearch_connection_check
fi

# Redis
if [[ -n "${REDIS_URL}" ]]; then
  redis_connection_check
fi

# RabbitMQ
if [[ -n "${MESSENGER_TRANSPORT_DSN}" ]]; then
  rabbitmq_connection_check
fi

# to be run in e.g. a Kubernetes initContainer
if [[ $1 == "setup" ]]; then
  log::green "Running Shopware 6 setup"
  # check if we even need a fresh installation, run deployment helper otherwise
  installed=$(is_shopware_installed)
  if [[ "$installed" == "true" ]]; then
    log::green "Shopware is installed. Running deployment helper to sync installation"
    # manually ensure messenger transports are set up since Deployment Helper fails to do so (23.01.25), regardless
    # of the Shopware documentation..
    # ref: https://developer.shopware.com/docs/guides/hosting/performance/performance-tweaks.html#disable-auto-setup
    shopware_setup_transports
    run_deployment_helper
  else
    log::green "Shopware was not found to be installed. Running initial installation"
    shopware_setup_transports
    shopware_install
    exit $?
  fi
fi

# first argument is a flag (e.g. -F)
if [[ ${1#-} != "$1" ]]; then
  set -- php-fpm "$@"
# run a message or cron worker
elif [[ $1 == "bin/console" ]]; then
  set -- php "$@"
fi

exec "$@"

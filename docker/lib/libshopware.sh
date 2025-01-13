#!/bin/bash

# shellcheck disable=SC1091

# Load Libraries
. /opt/adnoctem/scripts/liblog.sh
. /opt/adnoctem/scripts/libcheck.sh

# Constants
DOCROOT="$(pwd)"
SW_TOOL="${DOCROOT}/bin/console" # use console by default
STOREFRONT_LOCATIONS=(
	  'config/packages/storefront.yaml'
	  'config/packages/prod/storefront.yaml'
	  'config/packages/dev/storefront.yaml'
)

# deployment-helper - ensure we have some values set
export INSTALL_LOCALE="${INSTALL_LOCALE:-"de-DE"}"
export INSTALL_CURRENCY="${INSTALL_CURRENCY:-"EUR"}"
export INSTALL_ADMIN_USERNAME="${INSTALL_ADMIN_USERNAME:-"admin"}"
export INSTALL_ADMIN_PASSWORD="${INSTALL_ADMIN_PASSWORD:-"shopware"}"
export SALES_CHANNEL_URL="${APP_URL:-"shopware.internal"}"

#######################################
# Ensure we're in the project root.
# Globals:
#   DOCROOT
# Arguments:
#   None
# Returns:
#   0 if we are, 1 otherwise.
#######################################
ensure_project_root() {
	# check if current dir
	if [ ! -e "${DOCROOT}/composer.json" ]; then
		log "ERROR: script is not being executed from project root!"
		exit 1
	fi
}

#######################################
# Run commands within the built-in PHP console,
# with support for CI environments.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   The console the outputs.
#######################################
pc() {
	ensure_project_root

	# ensure is executable
	if [ ! -x "${SW_TOOL}" ]; then
		chmod +x "${SW_TOOL}"
	fi

	# use bin/ci in CI
	if [ "${CI:-""}" ]; then
		SW_TOOL="${PWD}/bin/ci"
	fi

	php -derror_reporting=E_ALL "${SW_TOOL}" "$@"
}

#######################################
# Install or setup Shopware.
# Globals:
#   INSTALL_LOCALE
#   INSTALL_CURRENCY
#   INSTALL_ADMIN_USERNAME
#   INSTALL_ADMIN_PASSWORD
#   SALES_CHANNEL_URL
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
deployment_helper() {
	echo "|--------------------------------------------------------------|"
	echo "|             Running Shopware Deployment Helper               |"
	echo "|--------------------------------------------------------------|"

	ensure_project_root
	if ! vendor/bin/shopware-deployment-helper run; then
		log "ERROR: Could not run Shopware Deployment-Helper! Exited with status $?"
	else
		log "Shopware Deployment-Helper executed successfully!"
	fi
}

#######################################
# Comment or uncomment storefront.yaml for
#   first deployments...
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
graceful_installation() {
  ensure_project_root
  if ! "${SW_TOOL}" system:is-installed; then
    log "Shopware 6 was not found to be installed. Installing Shopware..."
    comment_storefront_config
    deployment_helper
    uncomment_storefront_config
  fi
}

comment_storefront_config() {
  ensure_project_root
  log "Commenting Storefront configuration..."
	for location in "${STOREFRONT_LOCATIONS[@]}"; do
	    if [[ -e ${location} ]]; then
        log "Found configuration file: ${location} - commenting ..."
        # preserve comments
        sed -i -e 1,4b -e 's/^/# /' "${location}"
	    fi
	done
}

uncomment_storefront_config() {
  ensure_project_root
  log "Uncommenting Storefront configuration..."
	for location in "${STOREFRONT_LOCATIONS[@]}"; do
	    if [[ -e ${location} ]]; then
        echo "Found configuration file: ${location} - uncommenting ..."
        # preserve comments
        sed -i -e 1,4b -e 's/^# //' "${location}"
	    fi
	done
}

#######################################
# NOTE: DEPRECATED - USE 'deployment_helper'
# Clear the Shopware Cache for APP_ENV.
# Globals:
#   APP_ENV
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_clear_cache() {
	log "DEPRECATED: using deprecated Bash utility function 'shopware_clear_cache' please use 'deployment_helper' to run such tasks!"

	log "INFO: Clearing Shopware HTTP cache for environment \"$APP_ENV\""
	pc cache:clear --env="${APP_ENV}" -n
}

#######################################
# NOTE: DEPRECATED - USE 'deployment_helper'
# Install all Shopware extensions
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_install_extensions() {
	log "DEPRECATED: using deprecated Bash utility function 'shopware_install_extensions' please use 'deployment_helper' to install Shopware extensions!"

	list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)

	for plugin in $list_with_updates; do
		log "INFO: Installing Shopware plugin: ${plugin}"
		pc plugin:install --activate "$plugin"
	done
}

#######################################
# NOTE: DEPRECATED - USE 'deployment_helper'
# Update all Shopware extensions
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_update_extensions() {
	log "DEPRECATED: using deprecated Bash utility function 'shopware_update_extensions' please use 'deployment_helper' to update Shopware extensions!"

	list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.upgradeVersion != null)) | .[].name' -r)

	for plugin in $list_with_updates; do
		log "INFO: Updating Shopware 6 plugin: ${plugin}"
		pc plugin:update "$plugin"
	done
}

#######################################
# NOTE: DEPRECATED - USE 'deployment_helper'
# Set up a new Shopware installation.
# Globals:
#   INSTALL_LOCALE
#   INSTALL_CURRENCY
#   INSTALL_ADMIN_USERNAME
#   INSTALL_ADMIN_PASSWORD
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_install() {
	completed_at=$(date '+%Y-%m-%dT%H:%M:%S+00:00')
	storefront_name=Storefront

	log "INFO: Installing Shopware 6..."
	pc system:install --create-database "--shop-locale=${INSTALL_LOCALE:-"de-DE"}" "--shop-currency=${INSTALL_CURRENCY:-EUR}" --force
	pc user:create "${INSTALL_ADMIN_USERNAME:-admin}" --admin --password="${INSTALL_ADMIN_PASSWORD:-shopware}" -n
	pc sales-channel:create:storefront --name="${storefront_name}" --url="${APP_URL:-"http://localhost"}"
	pc theme:change --all "${storefront_name}"
	pc system:config:set core.frw.completedAt "${completed_at}"
	pc plugin:refresh
}

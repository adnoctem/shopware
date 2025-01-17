#!/bin/bash
#
# Copyright Ad Noctem Collective. All Rights Reserved.
# SPDX-License-Idenifier: MIT
#
# Library of Bash shell functions to handle various common Shopware 6 tasks like the full
# installation or separate steps like installing all plugins, clearing the HTTP cache, etc.

# shellcheck disable=SC1091

# Load Libraries
. /opt/adnoctem/lib/liblog.sh
. /opt/adnoctem/lib/libcheck.sh

# Constants
DOCROOT="$(pwd)"
SW_TOOL="${DOCROOT}/bin/console" # use console by default
STOREFRONT_LOCATIONS=(
	  'config/packages/storefront.yaml'
	  'config/packages/prod/storefront.yaml'
	  'config/packages/dev/storefront.yaml'
)
STOREFRONT_DESTINATION="/tmp/storefront"

# ensure we have the bare defaults set
export APP_ENV="${APP_ENV:-"dev"}"
export INSTALL_LOCALE="${INSTALL_LOCALE:-"de-DE"}"
export INSTALL_CURRENCY="${INSTALL_CURRENCY:-"EUR"}"
export INSTALL_ADMIN_USERNAME="${INSTALL_ADMIN_USERNAME:-"admin"}"
export INSTALL_ADMIN_PASSWORD="${INSTALL_ADMIN_PASSWORD:-"shopware"}"
export SALES_CHANNEL_NAME=${SALES_CHANNEL_NAME:-"Storefront"}
export SALES_CHANNEL_URL="${APP_URL:-"http://localhost:8000"}"
export SALES_CHANNEL_THEME=${SALES_CHANNEL_THEME:-"Storefront"}

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
# Ensure the storefront destination exists.
# Globals:
#   STOREFRONT_DESTINATION
# Arguments:
#   None
# Returns:
#   Nothing
#######################################
ensure_storefront_destination() {
	# check if current dir
	if [[ ! -d $STOREFRONT_DESTINATION ]]; then
		mkdir -p $STOREFRONT_DESTINATION
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
run_deployment_helper() {
	echo "|--------------------------------------------------------------|"
	echo "|             Running Shopware Deployment Helper               |"
	echo "|--------------------------------------------------------------|"

	ensure_project_root
	log::yellow "Starting Deployment Helper"
	exec vendor/bin/shopware-deployment-helper run
}

#######################################
# Run the Shopware CLI message worker.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Message worker outputs.
#######################################
run_message_worker() {
	echo "|--------------------------------------------------------------|"
	echo "|              Running Shopware Message Worker                 |"
	echo "|--------------------------------------------------------------|"

	ensure_project_root
	log::yellow "Starting Shopware message worker"
	exec pc messenger:consume --time-limit=360 --memory-limit=512M async low_priority
}

#######################################
# Run the Shopware CLI cron worker.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Message worker outputs.
#######################################
run_cron_worker() {
	echo "|--------------------------------------------------------------|"
	echo "|                Running Shopware Cron Worker                  |"
	echo "|--------------------------------------------------------------|"

	ensure_project_root
	log::yellow "Starting Shopware cron worker"
	exec pc scheduled-task:run --no-wait
}

#######################################
# (Re)move storefront.yaml to /tmp/storefront
#   for the first installation. Otherwise SW
#   complains about not having run theme:dump.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
move_storefront_config() {
  ensure_project_root

  log::yellow "Moving back Storefront configuration files..."
	for location in "${STOREFRONT_LOCATIONS[@]}"; do
	    if [[ -e "$STOREFRONT_DESTINATION/$location" ]]; then
        log::yellow "Found configuration file: $STOREFRONT_DESTINATION/$location - moving to $DOCROOT/$location"
        # sed -i -e 1,4b -e 's/^/# /' "${location}" -> legacy: comment all but the first 4 lines
        mv "$STOREFRONT_DESTINATION/$location" "$DOCROOT/$location"
        rm -rf "$STOREFRONT_DESTINATION"
	    fi
	done
}

#######################################
# (Re)move storefront.yaml to /tmp/storefront
#   for the first installation. Otherwise SW
#   complains about not having run theme:dump.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
remove_storefront_config() {
  ensure_project_root
  ensure_storefront_destination

  log::yellow "Moving Storefront configuration files hindering installation..."
	for location in "${STOREFRONT_LOCATIONS[@]}"; do
	    if [[ -e $location ]]; then
        log::yellow "Found configuration file: $location - moving to $STOREFRONT_DESTINATION"
        # sed -i -e 1,4b -e 's/^# //' "${location}" -> legacy: uncomment all but the first 4 lines
        mv "$location" "$STOREFRONT_DESTINATION"
	    fi
	done
}

#######################################
# Determine if Shopware is installed.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   0 if it is installed, 1 otherwise.
#######################################
is_shopware_installed() {
  if pc system:is-installed; then
    return 0
  else
    return 1
  fi
}

#######################################
# Clear the Shopware Cache for APP_ENV.
# Globals:
#   APP_ENV
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_clear_cache() {
	log::yellow "INFO: Clearing Shopware HTTP cache for environment \"$APP_ENV\""
	pc -n cache:clear --env="${APP_ENV}"
}

#######################################
# Install all Shopware plugins
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_install_plugins() {
	list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)
	for plugin in $list_with_updates; do
		log::yellow "INFO: Installing Shopware plugin: ${plugin}"
		pc -n plugin:install --activate "$plugin"
	done
}

#######################################
# Update all Shopware plugins
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_update_plugins() {
	list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.upgradeVersion != null)) | .[].name' -r)
	for plugin in $list_with_updates; do
		log::yellow "INFO: Updating Shopware 6 plugin: ${plugin}"
		pc -n plugin:update "$plugin"
	done
}

#######################################
# NOTE: DEPRECATED - USE 'deployment_helper'
# Set up a new Shopware installation.
# Globals:
#   APP_ENV
#   INSTALL_LOCALE
#   INSTALL_CURRENCY
#   INSTALL_ADMIN_USERNAME
#   INSTALL_ADMIN_PASSWORD
#   SALES_CHANNEL_URL
#   SALES_CHANNEL_THEME
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_install() {
	completed_at=$(date '+%Y-%m-%dT%H:%M:%S+00:00')
  log::green "INFO: Starting installation of Shopware 6 base system..."

  log::yellow "INFO: Removing Storefront configuration hindering Shopware installation!"
  remove_storefront_config

	log::yellow "INFO: Initializing database for Shopware"
	pc system:install --create-database "--shop-locale=$INSTALL_LOCALE" "--shop-currency=$INSTALL_CURRENCY" --force

	log::yellow "INFO: Creating user $INSTALL_ADMIN_USERNAME"
	pc user:create "$INSTALL_ADMIN_USERNAME" --admin --password="$INSTALL_ADMIN_PASSWORD" -n

	log::yellow "INFO: Creating $SALES_CHANNEL_NAME sales channel using theme with URL: $SALES_CHANNEL_URL"
	pc sales-channel:create:storefront --name="$SALES_CHANNEL_NAME" --url="$SALES_CHANNEL_URL"

  sales_channel_map=$(pc sales-channel:list --output json | jq -r '[.[] | {(.name|tostring): .id }] | add')
  sales_channel_id=$(echo "$sales_channel_map" | jq -r ".$SALES_CHANNEL_NAME")
  log::yellow "INFO: Configuring new sales channel $SALES_CHANNEL_THEME to use theme: $SALES_CHANNEL_THEME"
	pc theme:change -s "$sales_channel_id" "$SALES_CHANNEL_THEME"

	log::yellow "INFO: Setting installation completion date to: $completed_at"
	pc system:config:set core.frw.completedAt "$completed_at"

	log::yellow "INFO: Refreshing Shopware plugins"
	pc plugin:refresh

  log::yellow "INFO: Installing all Shopware plugins"
  shopware_install_plugins

  log::yellow "INFO: Restoring configuration and clearing Shopware cache for environment $APP_ENV"
  move_storefront_config
	shopware_clear_cache

	log::green "INFO: Successfully finished Shopware 6 installation!"
}

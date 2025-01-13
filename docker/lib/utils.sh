# shellcheck shell=bash

# Constants
DOCROOT="$(pwd)"
SW_TOOL="${DOCROOT}/bin/console" # use console by default
STOREFRONT_LOCATIONS=(
	  'config/packages/storefront.yaml'
	  'config/packages/prod/storefront.yaml'
	  'config/packages/dev/storefront.yaml'
)

# deployment-helper - ensure we have some values set
export INSTALL_LOCALE="${INSTALL_LOCALE:-"en-GB"}"
export INSTALL_CURRENCY="${INSTALL_CURRENCY:-"EUR"}"
export INSTALL_ADMIN_USERNAME="${INSTALL_ADMIN_USERNAME:-"admin"}"
export INSTALL_ADMIN_PASSWORD="${INSTALL_ADMIN_PASSWORD:-"shopware"}"
export SALES_CHANNEL_URL="${APP_URL:-"shopware.internal"}"
export SALES_CHANNEL_THEME="${SALES_CHANNEL_THEME:-"Storefront"}"
#######################################
# Log a line with the date and file.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   A time-stamped log line with the
#   executed file.
#######################################
log() {
	echo "[$(date '+%d-%m-%Y_%T')] $(basename "${0}"): ${*}"
}

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
# Check that the database connection available
# Globals:
#   DATABASE_URL
#   DATABASE_HOST
#   DATABASE_TIMEOUT
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
database_connection_check() {
	echo "|--------------------------------------------------------------|"
	echo "|       Checking for an active MySQL/MariaDB connection        |"
	echo "|--------------------------------------------------------------|"

	# shellcheck disable=SC2086
	database_host=${DATABASE_HOST:-"$(trurl "$DATABASE_URL" --get '{host}')"}
	database_port=${DATABASE_PORT:-"$(trurl "$DATABASE_URL" --get '{port}')"}
	tries=0

	until nc -z -w$((DATABASE_TIMEOUT + 20)) -v "$database_host" "${database_port:-3306}"; do
		log "Waiting $((DATABASE_TIMEOUT - tries)) more seconds for database connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${DATABASE_TIMEOUT}" ]; then
			log "FATAL: Could not connect to database within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done
}


#######################################
# Verify the ElasticSearch connection is
#   available.
# Globals:
#   OPENSEARCH_URL
#   OPENSEARCH_TIMEOUT
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
elasticsearch_connection_check() {
	echo "|--------------------------------------------------------------|"
	echo "|       Checking for an active ElasticSearch connection        |"
	echo "|--------------------------------------------------------------|"

	# shellcheck disable=SC2086
	es_host=${DATABASE_HOST:-"$(trurl "$OPENSEARCH_URL" --get '{host}')"}
	es_port=${DATABASE_PORT:-"$(trurl "$OPENSEARCH_URL" --get '{port}')"}
	tries=0

	until nc -z -w$((DATABASE_TIMEOUT + 20)) -v "$es_host" "${es_port:-9200}"; do
		log "Waiting $((DATABASE_TIMEOUT - tries)) more seconds for ElasticSearch connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${DATABASE_TIMEOUT}" ]; then
			log "FATAL: Could not connect to ElasticSearch within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done
}

#######################################
# Verify the Redis connection is
#   available.
# Globals:
#   REDIS_URL
#   REDIS_TIMEOUT
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
redis_connection_check() {
	echo "|--------------------------------------------------------------|"
	echo "|           Checking for an active Redis connection            |"
	echo "|--------------------------------------------------------------|"

	# shellcheck disable=SC2086
	redis_host=${DATABASE_HOST:-"$(trurl "$REDIS_URL" --get '{host}')"}
	redis_port=${DATABASE_PORT:-"$(trurl "$REDIS_URL" --get '{port}')"}
	tries=0

	until nc -z -w$((DATABASE_TIMEOUT + 20)) -v "$redis_host" "${redis_port:-6379}"; do
		log "Waiting $((DATABASE_TIMEOUT - tries)) more seconds for Redis connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${DATABASE_TIMEOUT}" ]; then
			log "FATAL: Could not connect to Redis within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done
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
install_or_setup() {
  ensure_project_root
  if ! "${SW_TOOL}" system:is-installed; then
    log "Shopware 6 was not found to be installed. Installing Shopware..."
    comment_storefront_config
    deployment_helper
    # re-initialize to fix frontend bug
    sales_channel_id=$(pc sales-channel:list --output json | jq -r '[.[] | {(.name|tostring): .id }] | add' | jq -r ".$SALES_CHANNEL_THEME")
    pc -n theme:change -s "$sales_channel_id" "$SALES_CHANNEL_THEME" --sync
    pc -n cache:clear
    uncomment_storefront_config
  else
    log "Shopware 6 is installed. Updating..."
    deployment_helper
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

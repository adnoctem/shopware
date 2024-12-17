# shellcheck shell=bash

# deployment-helper - ensure we have some values set
export INSTALL_LOCALE="${INSTALL_LOCALE:-"en-GB"}"
export INSTALL_CURRENCY="${INSTALL_CURRENCY:-"EUR"}"
export INSTALL_ADMIN_USERNAME="${INSTALL_ADMIN_USERNAME:-"admin"}"
export INSTALL_ADMIN_PASSWORD="${INSTALL_ADMIN_PASSWORD:-"shopware"}"
export SALES_CHANNEL_URL="${APP_URL:-"shopware.internal"}"

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
# Ensure we're in the project root.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if we are, 1 otherwise.
#######################################
ensure_project_root() {
	# check if current dir
	if [ ! -e "${ROOT}/composer.json" ]; then
		log "ERROR: script is not being executed from project root!"
		return 1
	fi

	return 0
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

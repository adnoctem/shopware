#!/bin/bash

# shellcheck disable=SC1091

# Load Libraries
. /opt/adnoctem/scripts/liblog.sh

# Constants
DATABASE_TIMEOUT=${DATABASE_TIMEOUT:-120}
OPENSEARCH_TIMEOUT=${OPENSEARCH_TIMEOUT:-120}
REDIS_TIMEOUT=${REDIS_TIMEOUT:-120}

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
		log::yellow "Waiting $((DATABASE_TIMEOUT - tries)) more seconds for database connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${DATABASE_TIMEOUT}" ]; then
			log::red "FATAL: Could not connect to database within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done

	log::green "Database connection is available!"
}


#######################################
# Verify the OpenSearch connection is
#   available.
# Globals:
#   OPENSEARCH_URL
#   OPENSEARCH_HOST
#   OPENSEARCH_PORT
#   OPENSEARCH_TIMEOUT
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
opensearch_connection_check() {
	echo "|--------------------------------------------------------------|"
	echo "|       Checking for an active ElasticSearch connection        |"
	echo "|--------------------------------------------------------------|"

	# shellcheck disable=SC2086
	es_host=${OPENSEARCH_HOST:-"$(trurl "$OPENSEARCH_URL" --get '{host}')"}
	es_port=${OPENSEARCH_PORT:-"$(trurl "$OPENSEARCH_URL" --get '{port}')"}
	tries=0

	until nc -z -w$((OPENSEARCH_TIMEOUT + 20)) -v "$es_host" "${es_port:-9200}"; do
		log:yellow "Waiting $((OPENSEARCH_TIMEOUT - tries)) more seconds for OpenSearch connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${OPENSEARCH_TIMEOUT}" ]; then
			log::red "FATAL: Could not connect to OpenSearch within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done

	log::green "OpenSearch connection is available!"
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
	redis_host=${REDIS_HOST:-"$(trurl "$REDIS_URL" --get '{host}')"}
	redis_port=${REDIS_PORT:-"$(trurl "$REDIS_URL" --get '{port}')"}
	tries=0

	until nc -z -w$((REDIS_TIMEOUT + 20)) -v "$redis_host" "${redis_port:-6379}"; do
		log::yellow "Waiting $((REDIS_TIMEOUT - tries)) more seconds for Redis connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${REDIS_TIMEOUT}" ]; then
			log::red "FATAL: Could not connect to Redis within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done

	log::green "Redis connection is available!"
}

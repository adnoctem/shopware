#!/bin/bash
#
# Copyright Ad Noctem Collective. All Rights Reserved.
# SPDX-License-Idenifier: MIT
#
# Library of Bash shell functions to check the availability of connections to various systems,
# by way of Bash's TCP/UDP support. See: https://www.man7.org/linux/man-pages/man1/bash.1.html
# The systems mainly are MySQL, OpenSearch, Redis and RabbitMQ although you're free to add to them.


# shellcheck disable=SC1091

# Load Libraries
. /opt/adnoctem/lib/liblog.sh

# Constants
CONNECTION_TIMEOUT=${CONNECTION_TIMEOUT:-5}
DATABASE_TRIES=${DATABASE_TRIES:-60}
OPENSEARCH_TRIES=${OPENSEARCH_TRIES:-60}
REDIS_TRIES=${REDIS_TRIES:-60}
RABBITMQ_TRIES=${RABBITMQ_TRIES:-60}

#######################################
# Check that the database connection available
# Globals:
#   DATABASE_URL
#   DATABASE_HOST
#   DATABASE_TIMEOUT
#   CONNECTION_TIMEOUT
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
	database_host=$(trurl "$DATABASE_URL" --get '{host}')
	database_port=$(trurl "$DATABASE_URL" --get '{port}')
	tries=0

  until nc -z -w"${CONNECTION_TIMEOUT}" -v "${database_host}" "${database_port:-3306}" 2>/dev/null; do
		log::yellow "Will try to establish a MySQL/MariaDB connection $((DATABASE_TRIES - tries)) more times"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -ge "${DATABASE_TRIES}" ]; then
			log::red "FATAL: Could not establish a connection to MySQL/MariaDB within ${tries} tries. Exiting..."
			exit 1
		fi
	done

	log::green "MySQL/MariaDB connection established!"
}


#######################################
# Verify the OpenSearch connection is
#   available.
# Globals:
#   OPENSEARCH_URL
#   OPENSEARCH_HOST
#   OPENSEARCH_PORT
#   OPENSEARCH_TIMEOUT
#   CONNECTION_TIMEOUT
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
	es_host=$(trurl "$OPENSEARCH_URL" --get '{host}')
	es_port=$(trurl "$OPENSEARCH_URL" --get '{port}')
	tries=0

  until nc -z -w"${CONNECTION_TIMEOUT}" -v "${es_host}" "${es_port:-9200}" 2>/dev/null; do
		log::yellow "Will try to establish a OpenSearch connection $((OPENSEARCH_TRIES - tries)) more times"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -ge "${OPENSEARCH_TRIES}" ]; then
			log::red "FATAL: Could not establish a connection to OpenSearch within ${tries} tries. Exiting..."
			exit 1
		fi
	done

	log::green "OpenSearch connection established!"
}

#######################################
# Verify the Redis connection is
#   available.
# Globals:
#   REDIS_URL
#   REDIS_TIMEOUT
#   CONNECTION_TIMEOUT
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
	redis_host=$(trurl "$REDIS_URL" --get '{host}')
	redis_port=$(trurl "$REDIS_URL" --get '{port}')
	tries=0

  until nc -z -w"${CONNECTION_TIMEOUT}" -v "${redis_host}" "${redis_port:-6379}" 2>/dev/null; do
		log::yellow "Will try to establish a Redis connection $((REDIS_TRIES - tries)) more times"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -ge "${REDIS_TRIES}" ]; then
			log::red "FATAL: Could not establish a connection to Redis within ${tries} tries. Exiting..."
			exit 1
		fi
	done

	log::green "Redis connection established!"
}

#######################################
# Verify the RabbitMQ connection is
#   available.
# Globals:
#   MESSENGER_TRANSPORT_DSN
#   RABBITMQ_TIMEOUT
#   CONNECTION_TIMEOUT
# Arguments:
#   None
# Outputs:
#   Logs remaining seconds on each iteration.
#######################################
rabbitmq_connection_check() {
	echo "|--------------------------------------------------------------|"
	echo "|         Checking for an active RabbitMQ connection           |"
	echo "|--------------------------------------------------------------|"

	# shellcheck disable=SC2086
	rabbitmq_host=$(trurl "$MESSENGER_TRANSPORT_DSN" --get '{host}')
	rabbitmq_port=$(trurl "$MESSENGER_TRANSPORT_DSN" --get '{port}')
	tries=0

  until nc -z -w"${CONNECTION_TIMEOUT}" -v "${rabbitmq_host}" "${rabbitmq_port:-5672}" 2>/dev/null; do
		log::yellow "Will try to establish a RabbitMQ connection $((RABBITMQ_TRIES - tries)) more times"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -ge "${RABBITMQ_TRIES}" ]; then
			log::red "FATAL: Could not establish a connection to RabbitMQ within ${tries} tries. Exiting..."
			exit 1
		fi
	done

	log::green "RabbitMQ connection established!"
}

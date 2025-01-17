#!/bin/bash
#
# Copyright Ad Noctem Collective. All Rights Reserved.
# SPDX-License-Idenifier: MIT
#
# Library of Bash shell functions to check the availability of connections to various systems,
# by way of Bash's TCP/UDP support. See: https://www.man7.org/linux/man-pages/man1/bash.1.html
# The systems mainly are MySQL, OpenSearch, Redis and RabbitMQ although others may be added.


# shellcheck disable=SC1091

# Load Libraries
. /opt/adnoctem/lib/liblog.sh

# Constants
DATABASE_TIMEOUT=${DATABASE_TIMEOUT:-120}
OPENSEARCH_TIMEOUT=${OPENSEARCH_TIMEOUT:-120}
REDIS_TIMEOUT=${REDIS_TIMEOUT:-120}
RABBITMQ_TIMEOUT=${RABBITMQ_TIMEOUT:-120}

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

	until timeout "${DATABASE_TIMEOUT}" bash -c "cat </dev/tcp/${database_host}/${database_port:-3306}" &>/dev/null; do
	  log::yellow "Waiting $((DATABASE_TIMEOUT - tries)) more seconds for MySQL/MariaDB connection to become available"
	  sleep 1
	  tries=$(( tries + 1))

    if [ "$tries" -eq "${DATABASE_TIMEOUT}" ]; then
      log::red "FATAL: Could not connect to MySQL/MariaDB within timeout of ${tries} seconds. Exiting."
      exit 1
    fi
	done

	log::green "MySQL/MariaDB connection is available!"
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

  until timeout "${OPENSEARCH_TIMEOUT}" bash -c "cat </dev/tcp/${es_host}/${es_port:-9200}" &>/dev/null; do
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

  until timeout "${REDIS_TIMEOUT}" bash -c "cat </dev/tcp/${redis_host}/${redis_port:-6379}" &>/dev/null; do
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

#######################################
# Verify the RabbitMQ connection is
#   available.
# Globals:
#   MESSENGER_TRANSPORT_DSN
#   RABBITMQ_TIMEOUT
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
	rabbitmq_host=${RABBITMQ_HOST:-"$(trurl "$MESSENGER_TRANSPORT_DSN" --get '{host}')"}
	rabbitmq_port=${RABBITMQ_PORT:-"$(trurl "$MESSENGER_TRANSPORT_DSN" --get '{port}')"}
	tries=0

  until timeout "${RABBITMQ_TIMEOUT}" bash -c "cat </dev/tcp/${rabbitmq_host}/${rabbitmq_port:-5672}" &>/dev/null; do
		log::yellow "Waiting $((RABBITMQ_TIMEOUT - tries)) more seconds for RabbitMQ connection to become available"
		sleep 1
		tries=$((tries + 1))

		if [ "$tries" -eq "${RABBITMQ_TIMEOUT}" ]; then
			log::red "FATAL: Could not connect to RabbitMQ within timeout of ${tries} seconds. Exiting."
			exit 1
		fi
	done

	log::green "RabbitMQ connection is available!"
}
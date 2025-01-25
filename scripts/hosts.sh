#!/usr/bin/env bash
#
# Configure the current Linux machine with custom hostnames for localhost in order to get the correct routing
# in staging and development environments.

# Libraries
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=scripts/lib/helpers.sh
. "${SCRIPT_DIR}/lib/helpers.sh"

# shellcheck source=scripts/lib/paths.sh
. "${SCRIPT_DIR}/lib/paths.sh"

# shellcheck source=scripts/lib/permissions.sh
. "${SCRIPT_DIR}/lib/permissions.sh"

# shellcheck source=scripts/lib/stdout.sh
. "${SCRIPT_DIR}/lib/stdout.sh"

# Constants
HOST_CONFIGS=(
	'/etc/hosts'
)

CONFIG_START="# SHOPWARE MANAGED START"
CONFIG_END="# SHOPWARE MANAGED END"

CONFIG=$(
	cat <<EOF
${CONFIG_START}
# This segment is managed by adnoctem/shopware - do not modify!

# adnoctem/shopware - Ad Noctem Collective Shopware 6
127.0.0.1               shopware.internal                             # Top-Level Domain
127.0.0.1               traefik.shopware.internal                     # Traefik dashboard subdomain
127.0.0.1               opensearch.shopware.internal                  # OpenSearch WebUI
127.0.0.1               mailpit.shopware.internal                     # Mailpit WebUI
127.0.0.1               phpmyadmin.shopware.internal                  # PHPMyAdmin
127.0.0.1               grafana.shopware.internal                     # Grafana
127.0.0.1               prometheus.shopware.internal                  # Prometheus
127.0.0.1               rabbitmq.shopware.internal                    # RabbitMQ Management

${CONFIG_END}
EOF
)
# ----------------------
#   'help' usage function
# ----------------------
function hosts::usage() {
	echo
	echo "Usage: $(basename "${0}") <COMMAND>"
	echo
	echo "add     - Insert the new configuration in ${HOST_CONFIGS[*]}"
	echo "remove  - Remove the configuration from ${HOST_CONFIGS[*]}"
	echo "help    - Print this usage information"
	echo
}

# ----------------------
#   'add' function
# ----------------------
function hosts::add() {
	log::yellow "Adding custom host configuration to ${HOST_CONFIGS[*]}"
	read -rp "Are you sure you want to modify the system host files ${HOST_CONFIGS[*]}? (y/N) " choice
	case "${choice}" in
	y | Y)
		log::green "Confirmed modification to host configuration files. Installing..."
		for cfg in "${HOST_CONFIGS[@]}"; do
			if [[ -w "${cfg}" ]]; then
				log::green "Adding hosts to $cfg as $(whoami)!"
				echo "$CONFIG" | tee -a "${cfg}" >/dev/null
			else
				log::green "Adding hosts to $cfg as root!"
				echo "$CONFIG" | lib::permissions::run_as_root tee -a "${cfg}" >/dev/null
			fi
		done
		;;
	*)
		log::yellow "Cancelled modification to host configuration files. No changes made."
		return 1
		;;
	esac
}

# ----------------------
#   'remove' function
# ----------------------
function hosts::remove() {
	local sed_result

	log::yellow "Removing custom host configuration from ${HOST_CONFIGS[*]}"
	read -rp "Are you sure you want to modify the system host file ${HOST_CONFIGS[*]}? (y/N) " choice
	case "${choice}" in
	y | Y)
		log::green "Confirmed modification to host configuration files. Removing..."
		for cfg in "${HOST_CONFIGS[@]}"; do
			if [[ -w "${cfg}" ]]; then
				log::green "Removing hosts from $cfg as $(whoami)!"
				sed_result=$(sed "/${CONFIG_START}/,/${CONFIG_END}/d" "${cfg}")
				echo "${sed_result}" >"${cfg}"
			else
				log::green "Removing hosts from $cfg as root!"
				sed_result=$(lib::permissions::run_as_root sed "/${CONFIG_START}/,/${CONFIG_END}/d" "${cfg}")
				echo "${sed_result}" | lib::permissions::run_as_root tee "${cfg}" >/dev/null
			fi
		done
		;;
	*)
		log::yellow "Cancelled modification to host configuration files. No changes made."
		return 1
		;;
	esac
}

# --------------------------------
#   MAIN
# --------------------------------
function main() {
	local cmd=${1}

	if [[ $# -gt 1 ]]; then
		HOST_CONFIGS+=("${@:2}")
	fi

	# add custom environment variable
	if [[ -n "${EXTRA_HOSTS_PATH}" ]]; then
		HOST_CONFIGS+=("${EXTRA_HOSTS_PATH}")
	fi

	case "${cmd}" in
	add)
		hosts::add
		return $?
		;;
	remove)
		hosts::remove
		return $?
		;;
	*)
		log::red "Unknown command: ${cmd}. See 'help' command for usage information:"
		hosts::usage
		return 1
		;;
	esac
}

# ------------
# 'main' call
# ------------
main "$@"

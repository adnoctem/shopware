#!/usr/bin/env bash
#
# Configure the current Linux machine with custom hostnames for localhost in order to get the correct routing
# in staging and development environments.

# Libraries
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=scripts/lib/paths.sh
. "${SCRIPT_DIR}/lib/paths.sh"

# shellcheck source=scripts/lib/perm.sh
. "${SCRIPT_DIR}/lib/perm.sh"

# shellcheck source=scripts/lib/log.sh
. "${SCRIPT_DIR}/lib/log.sh"

# Constants
HOST_CONFIG="/etc/hosts"

CONFIG_START="# SHOPWARE MANAGED START"
CONFIG_END="# SHOPWARE MANAGED END"

CONFIG=$(
	cat <<EOF
${CONFIG_START}
# This segment is managed by FMJdev's shopware - do not modify!

# fmjdev/shopware - FMJ Studios Shopware 6
127.0.0.1               shopware.internal                             # Top-Level Domain
127.0.0.1               traefik.shopware.internal                     # Traefik dashboard subdomain
127.0.0.1               opensearch.shopware.internal                  # OpenSearch WebUI
127.0.0.1               mailpit.shopware.internal                     # Mailpit WebUI

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
	echo "add     - Insert the new configuration in ${HOST_CONFIG}"
	echo "remove  - Remove the configuration from ${HOST_CONFIG}"
	echo "help    - Print this usage information"
	echo
}

# ----------------------
#   'add' function
# ----------------------
function hosts::add() {
	log::yellow "Adding custom host configuration to ${HOST_CONFIG}"
	read -rp "Are you sure you want to modify the system host file ${HOST_CONFIG}? (y/N) " choice
	case "${choice}" in
	y | Y)
		log::green "Confirmed modification to ${HOST_CONFIG}. Installing..."
		echo "$CONFIG" | perm::run_as_root tee -a "${HOST_CONFIG}" >/dev/null
		;;
	*)
		log::yellow "Cancelled modification to ${HOST_CONFIG}. No changes made."
		return 0
		;;
	esac
}

# ----------------------
#   'remove' function
# ----------------------
function hosts::remove() {
	log::yellow "Removing custom host configuration from ${HOST_CONFIG}"
	read -rp "Are you sure you want to modify the system host file ${HOST_CONFIG}? (y/N) " choice
	case "${choice}" in
	y | Y)
		log::green "Confirmed modification to ${HOST_CONFIG}. Removing..."
		perm::run_as_root sed -i "/${CONFIG_START}/,/${CONFIG_END}/d" ${HOST_CONFIG}
		;;
	*)
		log::yellow "Cancelled modification to ${HOST_CONFIG}. No changes made."
		return 0
		;;
	esac
}

# --------------------------------
#   MAIN
# --------------------------------
function main() {
	local cmd=${1}

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

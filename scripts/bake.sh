#!/usr/bin/env bash
#
# Configure the environment for Docker Buildkit Bake.

# Libraries
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(git rev-parse --show-toplevel)

# shellcheck source=scripts/lib/paths.sh
. "${SCRIPT_DIR}/lib/paths.sh"

# shellcheck source=scripts/lib/log.sh
. "${SCRIPT_DIR}/lib/log.sh"

# Constants
ENV_FILE="${ROOT_DIR}/.env"
BAKE_FILE="${ROOT_DIR}/docker/docker-bake.hcl"

# ----------------------
#   'help' usage function
# ----------------------
function hosts::usage() {
	echo
	echo "Usage: $(basename "${0}")"
	echo
	echo "help    - Print this usage information"
	echo
}

# ----------------------
#   'run' function
# ----------------------
function bake::run() {
	target=${1:-"default"}

	log::yellow "Running 'docker buildx bake'!"

  # shellcheck source=/dev/null
  source "${ENV_FILE}"

  docker buildx bake \
    --file "${BAKE_FILE}" \
    "${target}" \
    --print
}

# --------------------------------
#   MAIN
# --------------------------------
function main() {
	local cmd=${1}

	case "${cmd}" in
	help)
		log::red "Unknown command: ${cmd}. See 'help' command for usage information:"
		hosts::usage
		return 1
		;;
	*)
		bake::run "${1}"
		return $?
		;;
	esac
}

# ------------
# 'main' call
# ------------
main "$@"

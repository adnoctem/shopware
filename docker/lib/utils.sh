#!/usr/bin/env sh
# shellcheck shell=sh

# Environment variables
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export NPM_CONFIG_FUND=false
export NPM_CONFIG_AUDIT=false
export NPM_CONFIG_UPDATE_NOTIFIER=false
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export DISABLE_ADMIN_COMPILATION_TYPECHECK=true

CWD="$(pwd)"

# Constants
ROOT="${CWD}"
SW_TOOL="${ROOT}/bin/console" # use console by default
ENV_FILE="${ROOT}/.env"

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
# Load a .env file.
# Globals:
#   LOAD_DOTENV
# Arguments:
#   None
# Outputs:
#   None.
#######################################
load_dotenv() {
	LOAD_DOTENV=${LOAD_DOTENV:-"1"}

	if [ "$LOAD_DOTENV" = "0" ]; then
		return
	fi

	CURRENT_ENV=${APP_ENV:-"dev"}
	env_file="$1"

	# If we have an actual .env file load it
	if [ -e "$env_file" ]; then
		# shellcheck source=/dev/null
		. "$env_file"
	elif [ -e "$env_file.dist" ]; then
		# shellcheck source=/dev/null
		. "$env_file.dist"
	fi

	# If we have an local env file load it
	if [ -e "$env_file.local" ]; then
		# shellcheck source=/dev/null
		. "$env_file.local"
	fi

	# If we have an env file for the current env load it
	if [ -e "$env_file.$CURRENT_ENV" ]; then
		# shellcheck source=/dev/null
		. "$env_file.$CURRENT_ENV"
	fi

	# If we have an env file for the current env load it'
	if [ -e "$env_file.$CURRENT_ENV.local" ]; then
		# shellcheck source=/dev/null
		. "$env_file.$CURRENT_ENV.local"
	fi
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
# Clear the Shopware Cache for APP_ENV.
# Globals:
#   APP_ENV
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_clear_cache() {
	log "INFO: Clearing Shopware HTTP cache for environment \"$APP_ENV\""
	pc cache:clear --env="${APP_ENV}" -n
}

#######################################
# Install all Shopware extensions
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_install_extensions() {
	list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)

	for plugin in $list_with_updates; do
		log "INFO: Installing Shopware plugin: ${plugin}"
		pc plugin:install --activate "$plugin"
	done
}

#######################################
# Update all Shopware extensions
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_update_extensions() {
	list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.upgradeVersion != null)) | .[].name' -r)

	for plugin in $list_with_updates; do
		log "INFO: Updating Shopware 6 plugin: ${plugin}"
		pc plugin:update "$plugin"
	done
}

#######################################
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
	pc system:install --create-database "--shop-locale=${INSTALL_LOCALE:-"en-GB"}" "--shop-currency=${INSTALL_CURRENCY:-EUR}" --force
	pc user:create "${INSTALL_ADMIN_USERNAME:-admin}" --admin --password="${INSTALL_ADMIN_PASSWORD:-shopware}" -n
	pc sales-channel:create:storefront --name="${storefront_name}" --url="${APP_URL:-"http://localhost"}"
	pc theme:change --all "${storefront_name}"
	pc system:config:set core.frw.completedAt "${completed_at}"
	pc plugin:refresh
}

#######################################
# Set up an existing Shopware installation.
# Globals:
#   SHOPWARE_SKIP_ASSET_COPY
# Arguments:
#   None
# Outputs:
#   Shopware CLI outputs.
#######################################
shopware_setup() {
	log "INFO: Setting up Shopware 6 shop..."

	if [ -z "${SHOPWARE_SKIP_ASSET_COPY:-""}" ]; then pc plugin:update:all; else pc plugin:update:all --skip-asset-build; fi
	log "INFO: Running Shopware 6 plugin updates!"

	if [ -n "${SHOPWARE_SKIP_ASSET_COPY:-""}" ]; then pc system:update:finish --skip-asset-build; else pc system:update:finish; fi
	log "INFO: Finishing Shopware 6 update process!"
}

#######################################
# Install Shopware Composer dependencies.
# Globals:
#   SW_TOOL
#   SHOPWARE_SKIP_BUNDLE_DUMP
#   SHOPWARE_SKIP_FEATURE_DUMP
#   SHOPWARE_SKIP_ASSET_COPY
#   SHOPWARE_SKIP_THEME_COMPILE
#   SHOPWARE_SKIP_CLEAR_CACHE
# Arguments:
#   None
# Outputs:
#   Shopware build logs.
#######################################
shopware_install_dependencies() {
	ensure_project_root

  def_args="--prefer-dist --no-interaction"
  if [ "${APP_ENV:-"dev"}" = "prod" ]; then def_args="${def_args} --no-dev"; fi
  raw_args=$(echo "$def_args" | tr ' ' ' ' 2>/dev/null | while read -r item; do echo "$item "; done)
  args=$(echo "$raw_args" | awk '{$1=$1};1') # trim leading/trailing spaces

	if [ "$(command -v composer)" ]; then
    if ! composer install "${args}";
    then
      log "ERROR: Could not install Shopware dependencies!"
      return 1
    fi

    log "Installed Shopware dependencies!"
    return 0
	else
	  log "ERROR: Cannot install Shopware dependencies. Composer is not installed!"
	fi
}

#######################################
# Build the Shopware storefront.
# Adapted from bin/build-storefront.sh.
# Globals:
#   SW_TOOL
#   SHOPWARE_SKIP_BUNDLE_DUMP
#   SHOPWARE_SKIP_FEATURE_DUMP
#   SHOPWARE_SKIP_ASSET_COPY
#   SHOPWARE_SKIP_THEME_COMPILE
#   SHOPWARE_SKIP_CLEAR_CACHE
# Arguments:
#   None
# Outputs:
#   Shopware build logs.
#######################################
shopware_build_storefront() {
	ensure_project_root
	# old PWD
	OLD_WD=$(pwd)
	if [ -e "${CWD}/vendor/shopware/platform" ]; then
		STOREFRONT_ROOT="${STOREFRONT_ROOT:-"${CWD}/vendor/shopware/platform/src/Storefront"}"
	else
		STOREFRONT_ROOT="${STOREFRONT_ROOT:-"${CWD}/vendor/shopware/storefront"}"
	fi

	# build the storefront
	# shellcheck disable=SC2086
	[ ${SHOPWARE_SKIP_BUNDLE_DUMP:-""} ] || pc bundle:dump
	[ "${SHOPWARE_SKIP_FEATURE_DUMP:-""}" ] || pc feature:dump

	# parse var/plugins.json
	if [ "$(command -v jq)" ]; then
		jq -c '.[]' "var/plugins.json" | while read -r config; do
			path=$(echo "$config" | jq -r '(.basePath + .storefront.path)')

			# package.json should be in parent
			parent_path=$(dirname "$path")
			name=$(echo "$config" | jq -r '.technicalName')

			# skip if required
			skippingEnvVarName="SKIP_$(echo "$name" | sed -e 's/\([a-z]\)/\U\1/g' -e 's/-/_/g')"
			if [ "$(eval "echo \"\$$skippingEnvVarName\"")" ]; then
				continue
			fi

			if [ -f "$parent_path/package.json" ] && [ ! -d "$parent_path/node_modules" ] &&  [ "$name" != "storefront" ]; then
				log "-> Installing npm dependencies for ${name}"
				npm i --prefix "${parent_path}" --prefer-offline
			fi
		done
		# switch back
		cd "${OLD_WD}" || exit
	else
		log "ERROR: Could not check extensions for required npm installations - jq is not installed!"
		exit 1
	fi

	# build storefront
	npm --prefix "${STOREFRONT_ROOT}/Resources/app/storefront install --prefer-offline --production"
	node "${STOREFRONT_ROOT}/Resources/app/storefront/copy-to-vendor.js"
	npm --prefix "${STOREFRONT_ROOT}/Resources/app/storefront run production"

	# copy assets
	[ "${SHOPWARE_SKIP_ASSET_COPY:-""}" ] || pc assets:install
	[ "${SHOPWARE_SKIP_THEME_COMPILE:-""}" ] || pc theme:compile --active-only

	# clear cache
	[ "${SHOPWARE_SKIP_CLEAR_CACHE:-""}" ] || pc cache:clear
}

#######################################
# Build the Shopware administration.
# Adapted from bin/build-administration.sh.
# Globals:
#   SW_TOOL
#   SHOPWARE_SKIP_BUNDLE_DUMP
#   SHOPWARE_SKIP_ENTITY_SCHEMA_DUMP
# Arguments:
#   None
# Outputs:
#   Shopware build logs.
#######################################

shopware_build_administration() {
	ensure_project_root
	# old PWD
	OLD_WD=$(pwd)
  env=$(printenv)
	curenv=$(echo "$env" | sed -e 's/^/export /')
	load_dotenv "${ENV_FILE}"

	# Restore environment variables
	set -o allexport
	eval "${curenv}"
	set +o allexport

	if [ -e "${CWD}/vendor/shopware/platform" ]; then
		ADMIN_ROOT="${ADMIN_ROOT:-"${CWD}/vendor/shopware/platform/src/Administration"}"
	else
		ADMIN_ROOT="${ADMIN_ROOT:-"${CWD}/vendor/shopware/administration"}"
	fi

	# build the storefront
	pc feature:dump # is required, cannot be overwritten for admin
	[ "${SHOPWARE_SKIP_BUNDLE_DUMP:-""}" ] || pc bundle:dump

	# parse var/plugins.json
	if [ "$(command -v jq)" ]; then
		jq -c '.[]' "var/plugins.json" | while read -r config; do
			path=$(echo "$config" | jq -r '(.basePath + .administration.path)')

			# package.json should be in parent
			parent_path=$(dirname "$path")
			name=$(echo "$config" | jq -r '.technicalName')

			# skip if required
			skippingEnvVarName="SKIP_$(echo "$name" | sed -e 's/\([a-z]\)/\U\1/g' -e 's/-/_/g')"
			if [ "$(eval "echo \"\$$skippingEnvVarName\"")" ]; then
				continue
			fi

			if [ -f "$parent_path/package.json" ] &&  [ ! -d "$parent_path/node_modules" ] && [ "$name" != "administration" ]; then
				log "-> Installing npm dependencies for ${name}"
				npm i --prefix "${parent_path}" --prefer-offline
			fi
		done
		# switch back
		cd "${OLD_WD}" || exit
	else
		log "ERROR: Could not check extensions for required npm installations - jq is not installed!"
		exit 1
	fi

	(cd "${ADMIN_ROOT}" && npm install --prefer-offline --production)

	# dump PHP entity schema
	if [ -z "${SHOPWARE_SKIP_ENTITY_SCHEMA_DUMP:-""}" ] && [ -f "${ADMIN_ROOT}/Resources/app/administration/scripts/entitySchemaConverter/entity-schema-converter.ts" ]; then
		mkdir -p "${ADMIN_ROOT}/Resources/app/administration/test/_mocks_"
		pc -e prod framework:schema -s 'entity-schema' "${ADMIN_ROOT}/Resources/app/administration/test/_mocks_/entity-schema.json"
		(cd "${ADMIN_ROOT}/Resources/app/administration" && npm run convert-entity-schema)
	fi

	# build & copy assets
	(cd "${ADMIN_ROOT}/Resources/app/administration" && npm run build)
	[ "${SHOPWARE_SKIP_ASSET_COPY:-""}" ] || pc assets:install
}

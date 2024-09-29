#!/usr/bin/env bash
#
# Automate the download and build process for Shopware's PHP requirements - based on PHPBrew.
# ref: https://github.com/phpbrew/phpbrew

# Libraries
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=scripts/lib/paths.sh
#. "${SCRIPT_DIR}/lib/paths.sh"

# shellcheck source=scripts/lib/perm.sh
#. "${SCRIPT_DIR}/lib/perm.sh"

# shellcheck source=scripts/lib/log.sh
. "${SCRIPT_DIR}/lib/log.sh"

# Constants
DEFAULT_PHP_VERSION="8.2"
VERSION_REGEX="^[0-9]+\.[0-9]+(\.?[0-9]{1,2})?$"
VARIANTS=('default' 'curl' 'dom' 'fileinfo' 'fpm' 'gd' 'iconv' 'intl' 'json' 'xml' 'mbstring' 'openssl' 'pcre' 'pdo' 'mysql' 'phar' 'zlib' 'zip' 'opcache' 'sodium')
EXTENSIONS=('gd' 'opcache')
COMMUNITY_EXTENSIONS=('opentelemetry' 'grpc' 'redis')

# user-defined variables
PHP_VERSION=""

# ----------------------
#   library functions
# ----------------------
function php::lib::join() {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

function php::lib::ensure_phpbrew() {
	if [ ! "$(command -v phpbrew --version)" ]; then
    log "ERROR: Cannot install Shopware PHP. PHPBrew is not installed!"
    exit 1
	fi
}

function php::lib::switch_phpbrew_version() {
  local version
  env=$(declare -p -x)
  eval "$env"

  version=$(echo "${1}" |  xargs)
  pattern=$(printf "php-%s\.[0-9]+" "${version}")
	# shellcheck disable=SC2086
	# see L96
	sdk=$(phpbrew list | grep -Eo ${pattern})
	# shellcheck disable=SC2086
	# see L96
	if ! phpbrew switch $sdk; then
	  log::red "Could not switch PHP to PHPBrew version: $sdk"
	  return 1
	fi
	log::green "Switched to PHP version $version"
}

function php::lib::validate_version() {
  if ! echo "${PHP_VERSION}" | grep -qEo "${VERSION_REGEX}"; then
    log::red "Could not determine PHP version from given version: $php_version!"
    exit 1
  fi
}

# ----------------------
#   'help' usage function
# ----------------------
function php::usage() {
	echo
	echo "Usage: $(basename "${0}") <COMMAND> <VERSION>"
	echo
	echo "install     - Install PHP at the specified version"
	echo "configure   - Configure PHP.ini for Shopare's requirements"
	echo "help        - Print this usage information"
	echo
}

# ----------------------
#   'install' function
# ----------------------
function php::install() {
  version=$(echo "${PHP_VERSION}" | grep -Eo "${VERSION_REGEX}")
  procs=$(nproc)
  args="${VARIANTS[*]/#/+}"
  output=$(printf "/tmp/php_sh_%s_log.txt" "install")

  # PHP
	log::yellow "Installing custom PHP at version $version. Logging build output to $output."

  # shellcheck disable=SC2086
  # required because phpbrew won't accept quoted args
  if ! phpbrew install -j ${procs} ${version} ${args}>"${output}"; then
    log::red "Could not install custom PHP at version $version"
    return 1
  fi
  log::green "Installed PHP at version $version!"

  # switch PHP
  php::lib::switch_phpbrew_version "${version}"

  # Extensions
  log::yellow "Enabling PHP extensions: ${EXTENSIONS[*]}"
  for ext in "${EXTENSIONS[@]}"; do
    # enable
    if ! phpbrew ext enable "${ext}"; then
      log::red "Could not enable PHP extension: $ext"
      return 1
    fi
    log::green "Enabled PHP extension: $ext"
  done

  # Community Extensions
  log::yellow "Enabling PHP community extensions: ${COMMUNITY_EXTENSIONS[*]}"
  for cext in "${COMMUNITY_EXTENSIONS[@]}"; do
    # enable
    if ! pecl install "${cext}"; then
      log::red "Could not install PHP community extension: $cext"
      return 1
    fi
    log::green "Installed PHP community extension: $cext"
  done

  log::yellow "Run '$(basename "${0}") configure $version' to finish your PHP installation"
}

# ----------------------
#   'configure' function
# ----------------------
function php::configure() {
  version=$(echo "${PHP_VERSION}" | grep -Eo "${VERSION_REGEX}")
  ini=$(php -i | grep "Loaded Configuration File" | awk '{ print $5 }')

  # ensure correct PHP version
  php::lib::switch_phpbrew_version "${version}"

  # Shopware requires at least 512MB
  log::green "Configuring PHP memory_limit!"
  if ! sed -i 's/memory_limit\s*=.*/memory_limit=768M/g' "${ini}"; then
    log::red "Could not configure PHP memory_limit for php.ini: ${ini}!"
  fi
  log::green "Configured PHP memory_limit for php.ini: ${ini}!"

  # Shopware requires at least 512MB
  log::green "Configuring PHP opcache.memory_consumption!"
  if ! sed -i 's/;opcache.memory_consumption\s*=.*/opcache.memory_consumption=512/g' "${ini}"; then
    log::red "Could not configure PHP opcache.memory_consumption for php.ini: ${ini}!"
  fi
  log::green "Configured PHP opcache.memory_consumption for php.ini: ${ini}!"

  # Community Extensions
  log::yellow "Enabling PHP community extensions: ${COMMUNITY_EXTENSIONS[*]}"
  tmp_file=/tmp/php_sh_tmp_php.ini
  if [[ -f "${tmp_file}" ]]; then rm "${tmp_file}"; fi # delete the old one
  for cext in "${COMMUNITY_EXTENSIONS[@]}"; do
    echo "extension=${cext}.so" >> "${tmp_file}"
  done

  exts=$(<${tmp_file})
  if ! grep -qxF "$exts" "${ini}"; then
    echo "$exts" >> "${ini}"
  else
    log::yellow "Skipping configuration of ${ini} file for community extensions! File is already configured."
  fi

  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    log::red "Could not enable PHP community extensions: ${COMMUNITY_EXTENSIONS[*]}"
    return 1
  fi
  log::green "Enabled PHP community extensions: ${COMMUNITY_EXTENSIONS[*]}"
  log::green "Configured PHP $version for Shopware - Run 'phpbrew switch $sdk' to use it for your projects!"
}

# --------------------------------
#   MAIN
# --------------------------------
function main() {
  # NOTE: phpbrew isn't an executable so this HAS to stay here
  source "${HOME}/.phpbrew/bashrc"
	local cmd=${1} php_version=${2}

  # use defaults if not specified
  if [[ -z ${php_version} ]]; then
    PHP_VERSION="$DEFAULT_PHP_VERSION"
  else
    PHP_VERSION="$php_version"
  fi

  php::lib::ensure_phpbrew
  php::lib::validate_version "${@:2}"

	case "${cmd}" in
	install)
		php::install
		return $?
		;;
	configure)
		php::configure
		return $?
		;;
	help)
		php::usage
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

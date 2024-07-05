# logging
log() {
    echo "[$(date '+%d-%m-%Y_%T')] $(basename "${0}"): ${*}"
}

# Run commands within the built-in PHP console
pc() {
    php -derror_reporting=E_ALL bin/console "$@"
}

# Check that the database connection available
database_connection_check() {
  echo "|--------------------------------------------------------------|"
  echo "|       Checking for an active MySQL/MariaDB connection        |"
  echo "|--------------------------------------------------------------|"

  # shellcheck disable=SC2086
	database_host=${DATABASE_HOST:-"$(trurl "$DATABASE_URL" --get '{host}')"}
	database_port=${DATABASE_PORT:-"$(trurl "$DATABASE_URL" --get '{port}')"}
  tries=0

  until nc -z -w$(( DATABASE_TIMEOUT + 20 )) -v "$database_host" "${database_port:-3306}"
  do
    log "Waiting $(( DATABASE_TIMEOUT - tries )) more seconds for database connection to become available"
    sleep 1
    tries=$(( tries + 1 ))

    if [ "$tries" -eq "${DATABASE_TIMEOUT}" ]; then
      log "FATAL: Could not connect to database within timeout of ${tries} seconds. Exiting."
      exit 1
    fi
  done
}

# Install all Shopware 6 extensions
shopware_install_extensions() {
  list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)

  for plugin in $list_with_updates; do
    log "INFO: Installing Shopware 6 plugin: ${plugin}"
    pc plugin:install --activate "$plugin"
  done
}

# Update all Shopware 6 extensions
shopware_update_extensions() {
  list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.upgradeVersion != null)) | .[].name' -r)

  for plugin in $list_with_updates; do
    log "INFO: Updating Shopware 6 plugin: ${plugin}"
    pc plugin:update "$plugin"
  done
}
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

# Shopware (fresh) application installation
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

# Shopware (existing) application setup
shopware_setup() {
  log "INFO: Setting up Shopware 6 shop..."

  if [ -z "${SHOPWARE_SKIP_ASSET_COPY}" ]; then pc plugin:update:all; else pc plugin:update:all --skip-asset-build; fi
  log "INFO: Running Shopware 6 plugin updates!"

  if [ -n "${SHOPWARE_SKIP_ASSET_COPY}" ]; then pc system:update:finish --skip-asset-build; else pc system:update:finish; fi
  log "INFO: Finishing Shopware 6 update process!"
}
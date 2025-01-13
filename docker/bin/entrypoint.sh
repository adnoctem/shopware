#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load Libraries
. /opt/adnoctem/scripts/liblog.sh
. /opt/adnoctem/scripts/libcheck.sh
. /opt/adnoctem/scripts/libshopware.sh

#!/bin/bash

# Constants
# created with: https://patorjk.com/software/taag
BANNER=$(
cat <<- "EOF"
  ___      _   _   _            _                   _____       _ _           _   _
 / _ \    | | | \ | |          | |                 /  __ \     | | |         | | (_)
/ /_\ \ __| | |  \| | ___   ___| |_ ___ _ __ ___   | /  \/ ___ | | | ___  ___| |_ ___   _____
|  _  |/ _` | | . ` |/ _ \ / __| __/ _ \ '_ ` _ \  | |    / _ \| | |/ _ \/ __| __| \ \ / / _ \
| | | | (_| | | |\  | (_) | (__| ||  __/ | | | | | | \__/\ (_) | | |  __/ (__| |_| |\ V /  __/
\_| |_/\__,_| \_| \_/\___/ \___|\__\___|_| |_| |_|  \____/\___/|_|_|\___|\___|\__|_| \_/ \___|


 _____ _                                          ____
/  ___| |                                        / ___|
\ `--.| |__   ___  _ ____      ____ _ _ __ ___  / /___
 `--. \ '_ \ / _ \| '_ \ \ /\ / / _` | '__/ _ \ | ___ \
/\__/ / | | | (_) | |_) \ V  V / (_| | | |  __/ | \_/ |
\____/|_| |_|\___/| .__/ \_/\_/ \__,_|_|  \___| \_____/
                  | |
                  |_|
EOF
)

#######################################
# Print our Ad Noctem banner for Shopware 6.
#
# Globals:
#   BANNER
# Arguments:
#   None
# Outputs:
#   The banner.
#######################################
print_banner() {
  source_url="https://github.com/adnoctem/shopware"

  echo ""
  echo "${BANNER}"
  echo ""
  echo "Welcome to the Ad Noctem Collective build of Shopware 6!"
  echo "Read the entire source code on GitHub at: ${source_url}"
}

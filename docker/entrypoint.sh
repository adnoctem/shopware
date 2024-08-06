#!/usr/bin/env sh

DEFAULT_UID="1001"

if [ ${DEFAULT_UID} -ne "${PUID}" ]; then
  useradd -u "${PUID}" -o -c "" -m shopware
fi

exec gosu shopware swctl run &
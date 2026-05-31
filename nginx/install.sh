#!/usr/bin/env bash
# Cài config Nginx trên server (chạy với sudo)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_NAME="findsourcevn.conf"
SITES_AVAILABLE="${SITES_AVAILABLE:-/etc/nginx/sites-available}"
SITES_ENABLED="${SITES_ENABLED:-/etc/nginx/sites-enabled}"

cp "${SCRIPT_DIR}/${CONF_NAME}" "${SITES_AVAILABLE}/${CONF_NAME}"
ln -sf "${SITES_AVAILABLE}/${CONF_NAME}" "${SITES_ENABLED}/${CONF_NAME}"

if [[ -f "${SITES_ENABLED}/default" ]]; then
  rm -f "${SITES_ENABLED}/default"
  echo "Removed default site"
fi

nginx -t
systemctl reload nginx
echo "Installed ${CONF_NAME}. DNS → server IP, then certbot --nginx"

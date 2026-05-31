#!/usr/bin/env bash
# Tạo Secret từ deploy/k8s/.env.production
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env.production"
NAMESPACE="${NAMESPACE:-findsource}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Copy .env.production.example → .env.production và sửa giá trị"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic findsource-api-env \
  --namespace="${NAMESPACE}" \
  --from-literal=DB_DIALECT="${DB_DIALECT}" \
  --from-literal=DB_HOST=mysql \
  --from-literal=DB_PORT=3306 \
  --from-literal=DB_NAME="${DB_NAME}" \
  --from-literal=DB_USER="${DB_USERNAME}" \
  --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
  --from-literal=OFFICE_BE_PORT="${OFFICE_BE_PORT}" \
  --from-literal=FE_URLS="${FE_URLS}" \
  --from-literal=JWT_ACCESS_SECRET="${JWT_ACCESS_SECRET}" \
  --from-literal=JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET}" \
  --from-literal=JWT_ACCESS_EXPIRE_TIME="${JWT_ACCESS_EXPIRE_TIME}" \
  --from-literal=JWT_REFRESH_EXPIRE_TIME="${JWT_REFRESH_EXPIRE_TIME}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic findsource-mysql-env \
  --namespace="${NAMESPACE}" \
  --from-literal=MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  --from-literal=MYSQL_DATABASE="${MYSQL_DATABASE}" \
  --from-literal=MYSQL_USER="${MYSQL_USER}" \
  --from-literal=MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets created in namespace ${NAMESPACE}"

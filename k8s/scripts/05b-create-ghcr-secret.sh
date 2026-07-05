#!/usr/bin/env bash
# Tạo ghcr-secret từ deploy/k8s/.env.ghcr
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env.ghcr"
NAMESPACE="${NAMESPACE:-findsource}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Copy: cp .env.ghcr.example .env.ghcr && nano .env.ghcr"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${GITHUB_USER:?GITHUB_USER required in .env.ghcr}"
: "${GITHUB_PAT:?GITHUB_PAT required in .env.ghcr}"

kubectl create secret docker-registry ghcr-secret \
  --namespace="${NAMESPACE}" \
  --docker-server=ghcr.io \
  --docker-username="${GITHUB_USER}" \
  --docker-password="${GITHUB_PAT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ghcr-secret updated in namespace ${NAMESPACE}"

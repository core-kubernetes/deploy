#!/usr/bin/env bash
# Restore MySQL dump vào cluster
# Usage: bash 06-migrate-mysql.sh /path/to/findsource.sql
set -euo pipefail

DUMP_FILE="${1:?Usage: $0 findsource.sql}"
NAMESPACE="${NAMESPACE:-findsource}"

POD=$(kubectl get pod -n "${NAMESPACE}" -l app=mysql -o jsonpath='{.items[0].metadata.name}')
echo "Waiting for mysql pod ${POD}..."
kubectl wait --for=condition=ready pod/"${POD}" -n "${NAMESPACE}" --timeout=300s

kubectl cp "${DUMP_FILE}" "${NAMESPACE}/${POD}:/tmp/restore.sql"
kubectl exec -n "${NAMESPACE}" "${POD}" -- sh -c \
  'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" < /tmp/restore.sql'
echo "Restore done."

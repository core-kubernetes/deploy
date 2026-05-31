#!/usr/bin/env bash
# Backup MySQL ra file local
set -euo pipefail

NAMESPACE="${NAMESPACE:-findsource}"
OUT="${1:-findsource-backup-$(date +%Y%m%d-%H%M%S).sql}"

POD=$(kubectl get pod -n "${NAMESPACE}" -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${NAMESPACE}" "${POD}" -- \
  sh -c 'mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' > "${OUT}"
echo "Backup: ${OUT}"

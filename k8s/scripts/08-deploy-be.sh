#!/usr/bin/env bash
# Deploy MySQL + API (sau khi push ghcr.io/phamtuankhoi/findsource-api:production)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
NAMESPACE="${NAMESPACE:-findsource}"

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

if ! kubectl get secret ghcr-secret -n "${NAMESPACE}" &>/dev/null; then
  echo "Missing ghcr-secret in namespace ${NAMESPACE}."
  echo "Create it first:"
  echo "  kubectl create secret docker-registry ghcr-secret \\"
  echo "    --namespace=${NAMESPACE} \\"
  echo "    --docker-server=ghcr.io \\"
  echo "    --docker-username=PhamTuanKhoi \\"
  echo "    --docker-password=YOUR_GITHUB_PAT"
  exit 1
fi

if ! kubectl get secret findsource-api-env -n "${NAMESPACE}" &>/dev/null; then
  echo "Missing secrets. Run: bash scripts/05-create-secrets.sh"
  exit 1
fi

echo "Applying overlays/production-be (mysql + api + ingress)..."
kubectl apply -k "${ROOT}/overlays/production-be"

echo "Waiting for mysql..."
kubectl wait --for=condition=ready pod -l app=mysql -n "${NAMESPACE}" --timeout=300s

echo "Waiting for api rollout..."
kubectl rollout status deployment/api -n "${NAMESPACE}" --timeout=300s

echo ""
kubectl get pods,svc,ingress -n "${NAMESPACE}" -o wide
echo ""
echo "Test: curl -I https://be.emiu.site/process"

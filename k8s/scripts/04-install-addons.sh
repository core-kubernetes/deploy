#!/usr/bin/env bash
# Cài Helm + ingress-nginx + cert-manager (chạy trên cp-1)
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }

debug_ns() {
  local ns=$1
  echo ""
  echo "=== Debug namespace: $ns ==="
  kubectl get pods,svc,jobs -n "$ns" -o wide 2>/dev/null || true
  kubectl get events -n "$ns" --sort-by='.lastTimestamp' 2>/dev/null | tail -15 || true
  kubectl describe pods -n "$ns" 2>/dev/null | tail -80 || true
}

wait_controller() {
  local ns=$1 label=$2 timeout=${3:-600}
  echo "Waiting for pods ($label) in $ns (max ${timeout}s)..."
  if kubectl wait --namespace "$ns" \
    --for=condition=ready pod \
    --selector="$label" \
    --timeout="${timeout}s"; then
    return 0
  fi
  debug_ns "$ns"
  return 1
}

# Helm
if ! command -v helm >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

# Ingress — EC2 kubeadm: hostNetwork + pin worker-1 (DNS trỏ public IP worker-1)
# Tắt admission webhook (job patch hay timeout trên cluster nhỏ)
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.dnsPolicy=ClusterFirstWithHostNet \
  --set controller.service.type=ClusterIP \
  --set controller.watchIngressWithoutClass=true \
  --set controller.ingressClassResource.default=true \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.nodeSelector."kubernetes\.io/hostname"=worker-1 \
  --wait=false

wait_controller ingress-nginx app.kubernetes.io/component=controller 600

# cert-manager (tắt startupapicheck — job hook hay timeout trên cluster nhỏ)
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --set startupapicheck.enabled=false \
  --wait=false

wait_controller cert-manager app.kubernetes.io/component=controller 600 || \
wait_controller cert-manager app.kubernetes.io/component=webhook 600

echo ""
echo "Addons installed. Apply ClusterIssuer:"
echo "  kubectl apply -f base/cert-manager/cluster-issuer.yaml"

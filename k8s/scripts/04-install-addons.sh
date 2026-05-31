#!/usr/bin/env bash
# Cài Helm + ingress-nginx + cert-manager (chạy từ laptop hoặc node-1 có kubectl)
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }

# Helm
if ! command -v helm >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Ingress — NodePort 80/443 hoặc hostNetwork tùy VPS
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait

# cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait

echo "Addons installed. Apply ClusterIssuer:"
echo "  kubectl apply -f deploy/k8s/base/cert-manager/cluster-issuer.yaml"

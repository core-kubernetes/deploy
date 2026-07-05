#!/usr/bin/env bash
# Cài local-path-provisioner (kubeadm bare-metal / EC2 không có cloud disk)
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

if kubectl get storageclass local-path &>/dev/null; then
  echo "StorageClass local-path already exists."
else
  echo "Installing rancher/local-path-provisioner..."
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
  kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=120s
fi

# Đặt làm default StorageClass
kubectl annotate storageclass local-path \
  storageclass.kubernetes.io/is-default-class=true --overwrite

echo ""
kubectl get storageclass
echo ""
echo "Done. Re-run: bash scripts/08-deploy-be.sh"
echo "If PVC still Pending, delete stuck resources first:"
echo "  kubectl delete statefulset mysql deployment api -n findsource"
echo "  kubectl delete pvc --all -n findsource"
echo "  bash scripts/08-deploy-be.sh"

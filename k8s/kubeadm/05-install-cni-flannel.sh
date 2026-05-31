#!/usr/bin/env bash
# Cài Flannel CNI — chạy trên cp-1 sau kubeadm init
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "Waiting for nodes Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s || true
kubectl get nodes -o wide

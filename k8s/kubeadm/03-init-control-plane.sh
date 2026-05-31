#!/usr/bin/env bash
# Init Control Plane — CHỈ chạy trên cp-1 (server 1)
set -euo pipefail

: "${NODE_IP:?Set NODE_IP — IP mà API Server advertise (thường IP private hoặc public cp-1)}"

POD_CIDR="${POD_CIDR:-10.244.0.0/16}"

kubeadm init \
  --pod-network-cidr="${POD_CIDR}" \
  --apiserver-advertise-address="${NODE_IP}"

echo ""
echo "=== Control Plane initialized ==="
echo "Kubeconfig: /etc/kubernetes/admin.conf"
echo ""
echo "Trên cp-1 (user devops):"
echo "  mkdir -p \$HOME/.kube && sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config && sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "Tiếp theo: bash kubeadm/05-install-cni-flannel.sh"
echo ""
kubeadm token create --print-join-command

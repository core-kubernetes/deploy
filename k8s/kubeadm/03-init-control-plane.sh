#!/usr/bin/env bash
# Init Control Plane — CHỈ chạy trên cp-1 (server 1)
#
# Usage:
#   sudo bash 03-init-control-plane.sh
#   sudo bash 03-init-control-plane.sh 203.0.113.10
#   export NODE_IP=203.0.113.10 && sudo bash 03-init-control-plane.sh
set -euo pipefail

NODE_IP="${NODE_IP:-${1:-}}"
if [[ -z "${NODE_IP}" ]]; then
  NODE_IP="$(hostname -I | awk '{print $1}')"
fi
if [[ -z "${NODE_IP}" ]]; then
  echo "Không tự nhận được IP. Chạy:"
  echo "  sudo bash 03-init-control-plane.sh <IP_cp-1>"
  echo "IP phải là địa chỉ worker dùng để kubeadm join (thường IP private trong VPC)."
  exit 1
fi

POD_CIDR="${POD_CIDR:-10.244.0.0/16}"

echo "NODE_IP=${NODE_IP} (apiserver-advertise-address)"
echo "POD_CIDR=${POD_CIDR}"

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

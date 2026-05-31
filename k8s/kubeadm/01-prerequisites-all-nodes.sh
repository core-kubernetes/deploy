#!/usr/bin/env bash
# Chuẩn bị node cho kubeadm — chạy trên CẢ 3 node (cp-1, worker-1, worker-2)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

modprobe overlay
modprobe br_netfilter

cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# containerd cần cho kubeadm
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q active; then
  ufw allow 22/tcp
  ufw allow 6443/tcp
  ufw allow 10250/tcp
  ufw allow 8472/udp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw reload
fi

echo "Prerequisites OK: $(hostname)"

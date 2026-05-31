#!/usr/bin/env bash
# Join worker — chạy trên worker-1, worker-2
#
# Lấy lệnh join trên cp-1:
#   kubeadm token create --print-join-command
#
# Usage (khuyến nghị — 1 dòng, copy nguyên từ cp-1):
#   sudo bash 04-join-worker.sh 'kubeadm join 172.31.30.134:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx'
set -euo pipefail

JOIN_CMD="${1:-${JOIN_CMD:-}}"
if [[ -z "${JOIN_CMD}" ]]; then
  echo "Thiếu lệnh join. Trên cp-1 chạy:"
  echo "  kubeadm token create --print-join-command"
  echo "Rồi trên worker:"
  echo "  sudo bash 04-join-worker.sh '<paste cả dòng kubeadm join>'"
  exit 1
fi

eval "${JOIN_CMD}"
echo "Joined cluster: $(hostname)"

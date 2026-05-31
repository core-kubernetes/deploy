#!/usr/bin/env bash
# Join worker — chạy trên worker-1, worker-2
# Usage:
#   export JOIN_CMD='kubeadm join 10.0.0.1:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx'
#   sudo -E bash 04-join-worker.sh
set -euo pipefail

: "${JOIN_CMD:?Paste lệnh kubeadm join đầy đủ từ cp-1}"

eval "${JOIN_CMD}"
echo "Joined cluster: $(hostname)"

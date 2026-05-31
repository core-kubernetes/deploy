# Lỗi: `conntrack not found in system path` (kubeadm preflight)

## Triệu chứng

```text
sudo bash 03-init-control-plane.sh 172.31.30.134
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
	[ERROR FileExisting-conntrack]: conntrack not found in system path
```

Cả public IP và private IP đều fail cùng lỗi.

## Nguyên nhân

`kubeadm init` chạy **preflight checks** — yêu cầu gói `conntrack` (và thường cả `socat`, `ebtables`) trên **mọi node** sẽ tham gia cluster.

Ubuntu minimal / EC2 image đôi khi **không cài sẵn**.

## Cách fix

Trên **cp-1** (và **worker-1**, **worker-2** trước khi join):

```bash
sudo apt-get update
sudo apt-get install -y conntrack socat ebtables ethtool
```

Chạy lại init:

```bash
sudo bash 03-init-control-plane.sh 172.31.30.134
```

## Cách tránh

Chạy đủ prerequisites trên **cả 3 node** trước init/join:

```bash
sudo bash 01-prerequisites-all-nodes.sh
```

Script `01-prerequisites-all-nodes.sh` đã được cập nhật để cài `conntrack socat ebtables ethtool`.

## Liên quan

- [../kubeadm/01-prerequisites-all-nodes.sh](../kubeadm/01-prerequisites-all-nodes.sh)

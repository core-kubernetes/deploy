# Kubernetes chuẩn — kubeadm (1 Control Plane + 2 Worker)

Cài cluster **Kubernetes thật** cho findsource trên `emiu.site`.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   cp-1          │     │   worker-1      │     │   worker-2      │
│  Control Plane  │     │   Worker        │     │   Worker        │
│  API Server     │     │  kubelet        │     │  kubelet        │
│  etcd           │     │  kube-proxy     │     │  kube-proxy     │
│  Scheduler      │     │  containerd     │     │  containerd     │
│  Controller Mgr │     │  Pods (app)     │     │  Pods (app)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

Manifest app: [`../base/`](../base/), [`../overlays/production/`](../overlays/production/) — dùng sau khi cluster Ready.

---

## Phần cứng

| Server | Vai trò | Cấu hình |
|--------|---------|----------|
| **cp-1** | Control Plane | 2 vCPU, 4 GB, 40 GB SSD |
| **worker-1** | Worker | 4 vCPU, 8 GB, 100 GB SSD |
| **worker-2** | Worker | 4 vCPU, 8 GB, 100 GB SSD |

DNS `emiu.site` → IP **worker-1** (hoặc LB trước Ingress).

---

## Bước 1 — Cả 3 node

```bash
sudo hostnamectl set-hostname cp-1      # hoặc worker-1, worker-2
sudo bash kubeadm/01-prerequisites-all-nodes.sh
sudo bash kubeadm/02-install-containerd-kubeadm.sh
```

`/etc/hosts` trên cả 3 (IP thật):
```
10.0.0.1 cp-1
10.0.0.2 worker-1
10.0.0.3 worker-2
```

---

## Bước 2 — Init Control Plane (chỉ cp-1)

```bash
# IP private trong VPC (worker join cùng mạng) — hoặc public nếu worker ở ngoài
sudo bash kubeadm/03-init-control-plane.sh <IP_cp-1>
```

Thiết lập kubeconfig (user devops):
```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Bước 3 — CNI Flannel (cp-1)

```bash
bash kubeadm/05-install-cni-flannel.sh
kubectl get nodes
```

---

## Bước 4 — Join Worker (worker-1 & worker-2)

Lệnh từ output `kubeadm init` hoặc trên cp-1:
```bash
kubeadm token create --print-join-command
```

Trên mỗi worker:
```bash
export JOIN_CMD='kubeadm join ...'
sudo -E bash kubeadm/04-join-worker.sh
```

Kiểm tra:
```bash
kubectl get nodes -o wide
# cp-1       Ready   control-plane
# worker-1   Ready   <none>
# worker-2   Ready   <none>
```

---

## Bước 5 — Taint Control Plane (mặc định)

cp-1 **không** chạy app findsource — đúng chuẩn production:
```bash
kubectl describe node cp-1 | grep Taint
kubectl get pods -n findsource -o wide   # chỉ worker-*
```

Dev only — cho app lên cp-1 (không khuyến nghị prod):
```bash
kubectl taint nodes cp-1 node-role.kubernetes.io/control-plane:NoSchedule-
```

---

## Bước 6 — Deploy findsource

```bash
bash ../scripts/04-install-addons.sh
kubectl apply -f ../base/cert-manager/cluster-issuer.yaml
cp ../.env.production.example ../.env.production
bash ../scripts/05-create-secrets.sh
kubectl apply -k ../overlays/production
```

---

## Token hết hạn

Trên cp-1:
```bash
kubeadm token create --print-join-command
```

---

## Phase sau — HA 3 Control Plane

Khi đã quen: thêm 2 CP + Load Balancer cho API Server. Xem [Kubernetes HA](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/).

---

## Scripts

| File | Node |
|------|------|
| `01-prerequisites-all-nodes.sh` | cả 3 |
| `02-install-containerd-kubeadm.sh` | cả 3 |
| `03-init-control-plane.sh` | cp-1 |
| `04-join-worker.sh` | worker-1, worker-2 |
| `05-install-cni-flannel.sh` | cp-1 |

Lý thuyết: [`../../study-kubernetes/README.md`](../../study-kubernetes/README.md)

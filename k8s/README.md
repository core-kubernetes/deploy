# Findsource — Kubernetes Production (kubeadm)

Triển khai **production thật** findsource trên **Kubernetes chuẩn (kubeadm)**: 1 Control Plane + 2 Worker, domain **`emiu.site`**.

Cài cluster: **[`GETTING-STARTED.md`](./GETTING-STARTED.md)** ← **bắt đầu từ đây (làm trước, học sau)**  
Chi tiết kubeadm: [`kubeadm/README.md`](./kubeadm/README.md)

Học workload (Pod, Deployment, Ingress…): [`K8S-COMPONENTS.md`](./K8S-COMPONENTS.md)  
Học thành phần hệ thống (API Server, etcd…): [`../study-kubernetes/README.md`](../study-kubernetes/README.md)

---

## Domain — emiu.site

| URL | Service |
|-----|---------|
| `https://emiu.site` | Web |
| `https://www.emiu.site` | Web |
| `https://be.emiu.site` | API |
| `https://admin.emiu.site` | Admin |

DNS A record → IP **worker-1** (nơi nhận traffic Ingress) hoặc Load Balancer:

| Type | Name | Value |
|------|------|-------|
| A | `@` | `<IP>` |
| A | `www` | `<IP>` |
| A | `be` | `<IP>` |
| A | `admin` | `<IP>` |

---

## Kiến trúc cluster

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  cp-1           │     │  worker-1       │     │  worker-2       │
│  Control Plane  │     │  Worker         │     │  Worker         │
│  API + etcd     │     │  Pods + Ingress │     │  Pods           │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                        │                        │
         └────────────────────────┴────────────────────────┘
                           Kubernetes cluster
                                    │
                    emiu.site / be.emiu.site / admin.emiu.site
```

App findsource (api, web, admin, mysql) chạy trên **worker** — không trên cp-1 (taint mặc định).

---

## Phần cứng

| Server | Vai trò | Cấu hình |
|--------|---------|----------|
| **cp-1** | Control Plane | 2 vCPU, 4 GB, 40 GB SSD |
| **worker-1** | Worker (+ Ingress) | 4 vCPU, 8 GB, 100 GB SSD |
| **worker-2** | Worker | 4 vCPU, 8 GB, 100 GB SSD |

OS: Ubuntu 22.04 LTS.

---

## Lộ trình 6 tuần

### Tuần 1 — Chuẩn bị

- Đọc [`../study-kubernetes/01-tong-quan-kien-truc.md`](../study-kubernetes/01-tong-quan-kien-truc.md)
- Thuê 3 VPS, hostname `cp-1`, `worker-1`, `worker-2`
- DNS `emiu.site` trỏ về worker-1 (hoặc LB)
- Trên **cả 3 node**:
  ```bash
  sudo bash deploy/k8s/kubeadm/01-prerequisites-all-nodes.sh
  sudo bash deploy/k8s/kubeadm/02-install-containerd-kubeadm.sh
  ```

### Tuần 2 — kubeadm cluster

Theo [`kubeadm/README.md`](./kubeadm/README.md):

1. `cp-1`: init control plane + Flannel
2. `worker-1`, `worker-2`: join
3. `kubectl get nodes` → 3 Ready

### Tuần 3 — Addons

```bash
bash deploy/k8s/scripts/04-install-addons.sh   # ingress-nginx + cert-manager
kubectl apply -f deploy/k8s/base/cert-manager/cluster-issuer.yaml
kubectl create secret docker-registry ghcr-secret ... -n findsource
```

### Tuần 4 — Deploy findsource

```bash
cp deploy/k8s/.env.production.example deploy/k8s/.env.production
bash deploy/k8s/scripts/05-create-secrets.sh
kubectl apply -k deploy/k8s/overlays/production
```

### Tuần 5 — CI/CD

Copy [`ci/deploy-k8s.yml.example`](./ci/deploy-k8s.yml.example) vào từng repo, secret `KUBECONFIG`.

### Tuần 6 — Vận hành

```bash
bash deploy/k8s/scripts/07-backup-mysql.sh
curl -I https://be.emiu.site/process
```

---

## Cấu trúc thư mục

```
deploy/k8s/
├── README.md
├── kubeadm/              ← cài cluster (scripts 01–05)
├── K8S-COMPONENTS.md
├── base/                 ← manifest app
├── overlays/production/
├── scripts/              ← addons, secrets, migrate, backup
└── ci/
```

---

## kubectl thường dùng

```bash
kubectl get nodes -o wide
kubectl get pods -n findsource -o wide    # Pod chỉ trên worker
kubectl get all -n findsource
kubectl apply -k deploy/k8s/overlays/production
kubectl rollout undo deployment/api -n findsource
```

---

## Bước tiếp theo

1. [`kubeadm/README.md`](./kubeadm/README.md) — cài cluster
2. Khi 3 node Ready → addons → deploy app

**Lỗi thường gặp:** [errors/README.md](./errors/README.md) (conntrack, join timeout SG, NODE_IP…)

# Học Kubernetes — Các thành phần cốt lõi của cluster

Tài liệu này giải thích **các thành phần hệ thống** tạo nên một cluster Kubernetes, dựa trên trang chính thức:

- [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/) (tiếng Anh)
- [Các thành phần của Kubernetes](https://kubernetes.io/vi/docs/concepts/overview/components/) (tiếng Việt)

Đây là lớp **nền tảng** (control plane, node, addons) — khác với tài liệu workload (Pod, Deployment, Ingress…) trong [`../k8s/K8S-COMPONENTS.md`](../k8s/K8S-COMPONENTS.md).

---

## Sơ đồ tổng thể

```
                    ┌─────────────────────────────────────────┐
                    │         Kubernetes cluster               │
                    │                                          │
   Cloud provider   │  ┌──────────── Control Plane ──────────┐ │
   API (tuỳ chọn)◄──┼──│ api-server ◄──► etcd                │ │
                    │  │     ▲    ▲    ▲                      │ │
                    │  │     │    │    │                      │ │
                    │  │  sched  c-m  c-c-m (optional)       │ │
                    │  └─────┼────┼────┼──────────────────────┘ │
                    │        │    │    │                       │
                    │  ┌─────▼────▼────▼──────────────────────┐ │
                    │  │  Node 1          Node 2  ...         │ │
                    │  │  kubelet         kubelet              │ │
                    │  │  kube-proxy      kube-proxy           │ │
                    │  │  containerd      containerd           │ │
                    │  │  [Pods]          [Pods]               │ │
                    │  └──────────────────────────────────────┘ │
                    └─────────────────────────────────────────┘

        kubectl / CI ──HTTP──► api-server
```

Ảnh tham khảo trong tài liệu Kubernetes: control plane ở trung tâm, mọi kubelet/kube-proxy trên worker node đều giao tiếp với **API Server**.

---

## Hai vùng chính

| Vùng | Vai trò | Chạy ở đâu |
|------|---------|------------|
| **Control Plane** | Quản lý trạng thái toàn cluster | **cp-1** (server 1) |
| **Worker Node** | Chạy workload (Pod) | **worker-1**, **worker-2** |

---

## Mục lục tài liệu

### Tổng quan

| File | Nội dung |
|------|----------|
| [01-tong-quan-kien-truc.md](./01-tong-quan-kien-truc.md) | Cluster là gì, luồng dữ liệu, desired state |
| [02-linh-hoat-kien-truc.md](./02-linh-hoat-kien-truc.md) | Triển khai linh hoạt: dev → production, HA |

### Control Plane

| File | Thành phần |
|------|------------|
| [control-plane/README.md](./control-plane/README.md) | Tổng quan control plane |
| [control-plane/kube-apiserver.md](./control-plane/kube-apiserver.md) | API Server |
| [control-plane/etcd.md](./control-plane/etcd.md) | etcd |
| [control-plane/kube-scheduler.md](./control-plane/kube-scheduler.md) | Scheduler |
| [control-plane/kube-controller-manager.md](./control-plane/kube-controller-manager.md) | Controller Manager |
| [control-plane/cloud-controller-manager.md](./control-plane/cloud-controller-manager.md) | Cloud Controller Manager (tuỳ chọn) |

### Node

| File | Thành phần |
|------|------------|
| [node/README.md](./node/README.md) | Tổng quan node components |
| [node/kubelet.md](./node/kubelet.md) | kubelet |
| [node/kube-proxy.md](./node/kube-proxy.md) | kube-proxy |
| [node/container-runtime.md](./node/container-runtime.md) | Container runtime (CRI) |

### Addons

| File | Nội dung |
|------|----------|
| [addons/README.md](./addons/README.md) | DNS, Dashboard, monitoring, logging |

---

## Liên hệ project findsource

| Thành phần K8s | Trong deploy findsource |
|----------------|-------------------------|
| API Server + etcd | Mọi `kubectl apply -k deploy/k8s/overlays/production` |
| Scheduler | Chọn node cho Pod `api`, `web`, `mysql-0` |
| Controller Manager | Giữ `replicas: 2` cho Deployment api/web |
| kubelet + containerd | Pull image `ghcr.io/...` trên **worker** node |
| kube-proxy + Service | `api:7003`, `web:80` nội bộ cluster |
| Addon DNS | CoreDNS — `mysql.findsource.svc` |
| Ingress (addon/controller) | `deploy/k8s/base/ingress/` — `emiu.site` |

**Cài cluster:** [`../k8s/kubeadm/`](../k8s/kubeadm/README.md)

Manifest app: [`../k8s/base/`](../k8s/base/), [`../k8s/overlays/production/`](../k8s/overlays/production/).

---

## Thứ tự đọc đề xuất

1. [01-tong-quan-kien-truc.md](./01-tong-quan-kien-truc.md)
2. [control-plane/kube-apiserver.md](./control-plane/kube-apiserver.md) → [etcd](./control-plane/etcd.md)
3. [control-plane/kube-scheduler.md](./control-plane/kube-scheduler.md) + [kube-controller-manager.md](./control-plane/kube-controller-manager.md)
4. [node/kubelet.md](./node/kubelet.md) → [container-runtime.md](./node/container-runtime.md) → [kube-proxy.md](./node/kube-proxy.md)
5. [addons/README.md](./addons/README.md)
6. [02-linh-hoat-kien-truc.md](./02-linh-hoat-kien-truc.md)

---

## Lệnh kiểm tra nhanh (cluster kubeadm)

```bash
# Control plane pods (namespace kube-system)
kubectl get pods -n kube-system

# Thành phần trên từng node
kubectl get nodes -o wide
kubectl describe node <tên-node>

# Addon DNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

*Tài liệu học tập nội bộ — tham chiếu Kubernetes docs, không thay thế tài liệu chính thức.*

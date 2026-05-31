# Linh hoạt kiến trúc (Flexibility in Architecture)

Kubernetes **không bắt buộc** một cách triển khai duy nhất cho control plane và node components. Trang [Components](https://kubernetes.io/docs/concepts/overview/components/) nhấn mạnh: kiến trúc có thể thích ứng từ môi trường dev nhỏ đến production quy mô lớn.

---

## Các mô hình triển khai phổ biến

### 1. All-in-one (học / dev)

| Đặc điểm | Ví dụ |
|----------|--------|
| 1 máy chạy control plane + workload | Minikube, kind (chỉ dev local) |
| etcd trên cùng máy | Không dùng cho production findsource |
| Đơn giản, không HA | Không dùng cho production critical |

### 2. Tách master và worker

| Đặc điểm | Ví dụ |
|----------|--------|
| 1 master chỉ control plane | `kubeadm init` trên cp-1 |
| Worker join cluster | `kubeadm join` trên worker-1/2 |
| Master có taint, app trên worker | Production findsource khi scale |

### 3. Control plane HA

| Thành phần | Gợi ý production |
|------------|------------------|
| API Server | Nhiều instance sau load balancer |
| etcd | **3 hoặc 5** node (số lẻ, quorum) |
| Scheduler / Controller Manager | Active-passive hoặc leader election (mặc định trong K8s) |

Mất 1 node etcd trong cluster 3 node — vẫn ghi được. Mất 2 node — mất quorum.

### 4. Managed Kubernetes

Cloud (EKS, GKE, AKS) vận hành control plane; bạn quản lý worker node (hoặc serverless node). **Cloud Controller Manager** do nhà cung cấp chạy.

### 5. Bare metal / VPS (findsource)

| Thành phần | Thực tế |
|------------|---------|
| cloud-controller-manager | Thường **không** có — không AWS/GCP native LB |
| LoadBalancer Service | MetalLB, hoặc **Ingress + NodePort** |
| Storage | Local PV, NFS, CSI driver riêng |

---

## Thành phần có thể tách hoặc gộp

| Thành phần | Linh hoạt |
|------------|-----------|
| kube-apiserver | Scale ngang, nhiều replica |
| etcd | Cluster riêng, backup định kỳ |
| scheduler / controller-manager | Có thể chạy nhiều bản với leader election |
| kubelet | Bắt buộc mỗi node một instance |
| kube-proxy | Có thể thay bằng dataplane CNI (eBPF) — “optional” trong docs |
| Container runtime | Chọn containerd, CRI-O (kubeadm dùng containerd) |

---

## kubeadm và findsource

Cluster findsource dùng **kubeadm** — cài đúng từng component Kubernetes chuẩn:

- cp-1: API Server, etcd, Scheduler, Controller Manager
- worker-1/2: kubelet, kube-proxy, containerd, Pods app
- CNI Flannel cài riêng sau `kubeadm init`

Script: [`../k8s/kubeadm/`](../k8s/kubeadm/README.md)

---

## So sánh nhanh: dev → production

| Tiêu chí | Dev (minikube/kind) | Production (kubeadm) |
|----------|------------------|------------|
| HA control plane | Không | Có (nếu SLA cao) |
| Backup etcd | Tùy chọn | Bắt buộc |
| Số worker | 1 | 2+ |
| Monitoring addon | Tùy | Prometheus / metrics-server |
| Ingress + TLS | cert-manager + Let's Encrypt | Giống `deploy/k8s/base/cert-manager/` |

---

## Tài liệu sâu hơn (Kubernetes chính thức)

- [Cluster Architecture](https://kubernetes.io/docs/concepts/architecture/)
- [Nodes](https://kubernetes.io/docs/concepts/architecture/nodes/)
- [Communication between Nodes and the Control Plane](https://kubernetes.io/docs/concepts/architecture/control-plane-node-communication/)

---

## Checklist khi thiết kế cluster findsource

- [ ] Số node worker đủ cho `replicas` + dự phòng khi drain node
- [ ] etcd backup (khác backup MySQL app — xem `07-backup-mysql.sh`)
- [ ] Addon DNS hoạt động (`kubectl get svc -n kube-system`)
- [ ] Ingress controller + cert-manager
- [ ] Không chạy workload nặng trên master nếu master yếu

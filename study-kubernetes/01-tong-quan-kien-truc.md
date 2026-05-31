# Tổng quan kiến trúc Kubernetes cluster

## Cluster là gì?

Một **Kubernetes cluster** gồm:

1. **Control plane** — “bộ não”: lưu trạng thái, nhận lệnh, lập lịch, điều chỉnh cluster cho khớp với cấu hình mong muốn.
2. **Một hoặc nhiều worker node** — “cơ bắp”: máy thật hoặc VM chạy ứng dụng (Pod).

Bạn **không** SSH vào từng container để scale. Bạn gửi **khai báo** (YAML) tới API; các thành phần hệ thống phối hợp để cluster đạt trạng thái đó.

---

## Mô hình desired state (trạng thái mong muốn)

```
┌──────────────┐     apply      ┌─────────────┐     lưu      ┌──────┐
│ kubectl / CI │ ─────────────► │ API Server  │ ───────────► │ etcd │
└──────────────┘                └──────┬──────┘              └──────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
              Scheduler          Controller Mgr        kubelet (mỗi node)
              (gán node)         (đủ Pod, Service...)  (chạy container)
```

| Khái niệm | Ý nghĩa |
|-----------|---------|
| **Desired state** | “Tôi muốn 2 Pod api, image tag X” — trong etcd |
| **Actual state** | Pod đang chạy, đã crash, thiếu replica — quan sát được qua API |
| **Reconciliation** | Controller + kubelet liên tục sửa lệch giữa desired và actual |

Ví dụ findsource: `spec.replicas: 2` trong Deployment api → nếu một Pod chết, **ReplicaSet controller** (trong controller-manager) yêu cầu tạo Pod mới → **Scheduler** chọn node → **kubelet** trên node đó khởi chạy container.

---

## Phân loại thành phần (theo docs chính thức)

### Core — Control Plane

Quản lý **trạng thái toàn cluster**:

| Thành phần | Một câu |
|------------|---------|
| kube-apiserver | Cổng REST duy nhất; mọi thao tác đi qua đây |
| etcd | Kho lưu trữ key-value cho dữ liệu API |
| kube-scheduler | Gán Pod chưa có node → node phù hợp |
| kube-controller-manager | Chạy các vòng lặp controller (Deployment, Node, …) |
| cloud-controller-manager | Tích hợp cloud (LB, disk, route) — **tuỳ chọn** |

Chi tiết: thư mục [control-plane/](./control-plane/).

### Core — Node

Chạy **trên mỗi node**, duy trì môi trường runtime:

| Thành phần | Một câu |
|------------|---------|
| kubelet | Đảm bảo Pod/container trên node đúng spec |
| kube-proxy | Rule mạng cho Service — **tuỳ chọn** trên một số kiến trúc CNI |
| Container runtime | containerd, CRI-O… — thực sự chạy container |

Chi tiết: thư mục [node/](./node/).

### Addons

Phần mềm **bổ sung** cluster (thường chạy dạng Pod trong `kube-system`):

- DNS (CoreDNS)
- Dashboard
- Monitoring / logging cluster-wide

Chi tiết: [addons/README.md](./addons/README.md).

---

## Ai nói chuyện với ai?

```
                    ┌─────────────────┐
                    │   API Server    │◄──── kubectl, operators, webhooks
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
      etcd              Scheduler          Controller Manager
   (persist)            (watch Pod           (watch mọi
                        unscheduled)          resource)

   Mỗi Node:
   kubelet ──watch/list──► API Server
   kube-proxy ──watch──► Service/EndpointSlice
   kubelet ──CRI──► containerd ──► containers
```

**Quy tắc quan trọng:** kubelet **không** nhận lệnh trực tiếp từ kubectl. kubectl chỉ gọi API Server; kubelet **watch** API Server để biết Pod nào phải chạy trên node mình.

---

## Control plane vs workload

| | Control plane | Workload (app của bạn) |
|---|---------------|------------------------|
| Ví dụ | api-server, etcd, scheduler | Pod findsource-api, mysql |
| Namespace thường gặp | `kube-system` | `findsource` |
| Taint master | `NoSchedule` — Pod app trên worker | Chạy trên worker-1/2 |
| Dev local | minikube/kind trên laptop | — |

Production lớn: tách master HA (3+ control plane) và nhiều worker.

---

## Thuật ngữ liên quan (đọc tiếp)

- **Pod** — đơn vị deploy nhỏ nhất; do kubelet quản lý trên node.
- **Node** — object trong API đại diện một máy; kubelet báo cáo capacity/health.
- **Namespace** — cách chia logic cluster (`findsource`, `kube-system`).

Workload và networking: [`../k8s/K8S-COMPONENTS.md`](../k8s/K8S-COMPONENTS.md) mục 5–6.

---

## Bài tập tư duy

1. Bạn `kubectl delete pod api-xxx` — thành phần nào tạo Pod mới?
2. `kubectl apply` Deployment `replicas: 3` nhưng cluster chỉ còn RAM cho 2 Pod — Scheduler và controller làm gì?
3. Mất etcd không backup — tại sao cluster “mù” dù container vẫn chạy?

*Gợi ý: (1) ReplicaSet/Deployment controller + Scheduler + kubelet. (2) Scheduler pending, có thể Pod ở trạng thái Pending. (3) Mất desired state trong etcd.*

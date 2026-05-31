# kube-controller-manager

## Định nghĩa

**kube-controller-manager** chạy các **controller** — vòng lặp liên tục so sánh **trạng thái mong muốn** (trong API/etcd) với **trạng thái thực tế**, rồi thực hiện hành động để hai phía khớp nhau.

> *"Runs controllers to implement Kubernetes API behavior."*

---

## Mô hình controller

```
watch / list resource
        ↓
So sánh spec (desired) vs status (actual)
        ↓
Nếu lệch → create/update/delete object khác
        ↓
Lặp lại (reconcile loop)
```

Đây là cơ chế **self-healing** của Kubernetes.

---

## Một số controller quan trọng

| Controller | Nhiệm vụ ví dụ |
|------------|-----------------|
| **Deployment** | Quản lý ReplicaSet, rolling update |
| **ReplicaSet** | Giữ đúng số Pod có label khớp |
| **StatefulSet** | Pod có tên ổn định, PVC theo Pod |
| **DaemonSet** | 1 Pod trên mỗi node (thỏa selector) |
| **Job** | Hoàn thành N lần chạy Pod |
| **Node** | Cập nhật trạng thái node, eviction khi NotReady |
| **Service / EndpointSlice** | Danh sách IP Pod backend cho Service |
| **PersistentVolume** | Bind PV ↔ PVC |
| **Namespace** | Finalizer khi xóa namespace |
| **TTL / Garbage collection** | Dọn object hết hạn |

Tất cả gói trong **một process** `kube-controller-manager` (có thể tách trong kiến trúc tùy biến nâng cao).

---

## Ví dụ findsource: Deployment api

```
Desired: replicas: 2 (trong Deployment spec)
Actual:  1 Pod Running (1 Pod crash)

ReplicaSet controller:
  → tạo Pod mới
Scheduler:
  → gán node
kubelet:
  → start container findsource-api
```

```bash
kubectl get rs -n findsource
kubectl describe deployment api -n findsource
```

---

## Rolling update

Deployment controller điều khiển chiến lược `RollingUpdate`:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

Tạo Pod mới → ready → terminate Pod cũ — không cần kubectl từng bước.

```bash
kubectl rollout status deployment/api -n findsource
```

---

## Khác với kubelet

| | controller-manager | kubelet |
|---|-------------------|---------|
| Chạy trên | Control plane node | **Mỗi** worker |
| Phạm vi | Toàn cluster (logic API) | **Một** node |
| Tạo Pod object | Có (qua API) | Không |
| Chạy container | Không | Có |

---

## HA

Nhiều instance với **leader election** — chỉ leader chạy controller nhất định (tránh conflict).

---

## Tài liệu tham khảo

- [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [kube-controller-manager](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/)

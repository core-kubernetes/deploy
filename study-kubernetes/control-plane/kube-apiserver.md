# kube-apiserver

## Định nghĩa

**kube-apiserver** là thành phần **front-end** của control plane: máy chủ expose **Kubernetes HTTP API** (REST). Mọi thao tác quản trị và hầu hết giao tiếp nội bộ cluster đều đi qua API Server.

> *"The core component server that exposes the Kubernetes HTTP API."* — [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)

---

## Vai trò

| Vai trò | Mô tả |
|---------|--------|
| **Cổng duy nhất** | kubectl, dashboard, controllers, kubelet đều gọi API (kubelet watch/list) |
| **Validation & admission** | Kiểm tra schema, RBAC, webhook (Pod Security, mutating/validating) |
| **Giao tiếp etcd** | Đọc/ghi object; etcd không expose trực tiếp cho user |
| **Watch stream** | Client watch resource → nhận event khi object thay đổi |

---

## Ai gọi API Server?

```
kubectl apply -f deployment.yaml
GitHub Actions (kubectl / helm)
kube-scheduler, kube-controller-manager
kubelet (mỗi node)
Operators, Ingress controller, cert-manager
Metrics server, CoreDNS (cập nhật Endpoints)
```

**Findsource:** mỗi lần CI chạy `kubectl apply -k overlays/production` → request tới API Server → lưu Deployment/Ingress/Secret vào etcd.

---

## API groups (ý tưởng)

| Nhóm | Ví dụ resource |
|------|----------------|
| **core** (`/api/v1`) | Pod, Service, Secret, Namespace, Node |
| **apps/v1** | Deployment, ReplicaSet, StatefulSet, DaemonSet |
| **networking.k8s.io/v1** | Ingress, NetworkPolicy |
| **batch/v1** | Job, CronJob |

```bash
kubectl api-resources
kubectl api-versions
```

---

## Authentication & Authorization

Trước khi xử lý request:

1. **Authentication** — xác định *ai* (cert, token, OIDC…)
2. **Authorization** — *được phép* gì (RBAC phổ biến nhất)
3. **Admission control** — *có chấp nhận object* không (limit, PSS, webhook)

```bash
kubectl auth can-i create pods -n findsource
kubectl auth whoami
```

---

## High Availability

Production thường chạy **nhiều replica** API Server phía sau load balancer:

- Client (kubectl) trỏ tới VIP/LB
- Mọi replica đọc/ghi **cùng cluster etcd**
- Phải đồng bộ thời gian (NTP) giữa các node

---

## Khắc phục sự cố

| Triệu chứng | Hướng xử lý |
|-------------|-------------|
| `kubectl` timeout | API Server down, firewall, cert hết hạn |
| `Forbidden` | RBAC — kiểm tra RoleBinding |
| `Invalid` / webhook reject | Admission — xem manifest, PSS |
| etcd chậm | API latency tăng toàn cluster |

```bash
kubectl get --raw /healthz
kubectl get --raw /readyz
```

---

## Liên hệ findsource

- Manifest: `deploy/k8s/base/**/*.yaml`
- Mọi object `metadata.namespace: findsource` được lưu qua API Server
- Ingress `be.emiu.site` — object Ingress trong API; controller riêng đọc watch

---

## Tài liệu tham khảo

- [The Kubernetes API](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)
- [Controlling Access to the Kubernetes API](https://kubernetes.io/docs/concepts/security/controlling-access/)
- [kube-apiserver](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)

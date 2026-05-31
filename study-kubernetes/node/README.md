# Node Components — Thành phần trên mỗi Node

**Node** (worker hoặc control plane) chạy các agent và runtime để **thực thi** Pod. Control plane quyết định *cái gì* chạy ở đâu; node components đảm bảo *nó thực sự chạy* đúng spec.

---

## Ba thành phần chính (theo docs)

| Thành phần | File | Ghi chú |
|------------|------|---------|
| kubelet | [kubelet.md](./kubelet.md) | Bắt buộc |
| kube-proxy | [kube-proxy.md](./kube-proxy.md) | Tuỳ chọn / thay thế bởi CNI |
| Container runtime | [container-runtime.md](./container-runtime.md) | containerd, CRI-O… |

Phần mềm bổ sung trên node (Linux): **systemd** giám sát process, **CNI plugin** cấu hình mạng Pod — không phải “core component” trong trang Components nhưng thực tế cần có.

---

## Object Node trong API

Mỗi máy tham gia cluster có resource **Node**:

```bash
kubectl get nodes
kubectl describe node <name>
```

| Field | Ý nghĩa |
|-------|---------|
| `status.capacity` | CPU, memory tổng |
| `status.allocatable` | Trừ system reserved |
| `status.conditions` | Ready, MemoryPressure, DiskPressure… |
| `spec.taints` | Chặn Pod không có toleration |

kubelet **báo cáo** heartbeat và capacity lên API Server.

---

## Luồng trên một node

```
API Server: "Pod api-xyz chạy trên node worker-1"
        ↓
kubelet (worker-1) nhận qua watch
        ↓
Pull image → tạo sandbox → start container (qua CRI)
        ↓
Mount volume, chạy probes
        ↓
Cập nhật Pod status → API Server
        ↓
kube-proxy (nếu có) cập nhật rule cho Service backend
```

---

## Đọc tiếp

- [kubelet.md](./kubelet.md)
- [container-runtime.md](./container-runtime.md)
- [kube-proxy.md](./kube-proxy.md)
- [../control-plane/kube-scheduler.md](../control-plane/kube-scheduler.md)

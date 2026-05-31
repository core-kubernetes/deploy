# Control Plane — Bộ điều khiển cluster

**Control plane** quản lý **trạng thái toàn cluster**. Nó không phải nơi ứng dụng của bạn “nên” chạy trong mô hình chuẩn (master thường có **taint** `node-role.kubernetes.io/control-plane:NoSchedule`), nhưng mọi quyết định về Pod, Service, Secret… đều xuất phát từ đây.

---

## Vai trò trong một câu

> Nhận khai báo từ người dùng/API, lưu vào etcd, lập lịch Pod, và chạy các vòng lặp để cluster **luôn tiến về** trạng thái mong muốn.

---

## Các thành phần

| Thành phần | File chi tiết | Bắt buộc? |
|------------|---------------|-----------|
| kube-apiserver | [kube-apiserver.md](./kube-apiserver.md) | Có |
| etcd | [etcd.md](./etcd.md) | Có |
| kube-scheduler | [kube-scheduler.md](./kube-scheduler.md) | Có |
| kube-controller-manager | [kube-controller-manager.md](./kube-controller-manager.md) | Có |
| cloud-controller-manager | [cloud-controller-manager.md](./cloud-controller-manager.md) | Tuỳ chọn (cloud) |

---

## Luồng xử lý Pod mới

```
1. kubectl apply Deployment (replicas: 2)
        ↓
2. API Server validate + ghi etcd
        ↓
3. Deployment controller tạo ReplicaSet + 2 Pod object (chưa có nodeName)
        ↓
4. Scheduler gán spec.nodeName cho từng Pod
        ↓
5. kubelet trên node được chọn tạo container
```

---

## Kiểm tra trên cluster thật

```bash
# Pod hệ thống control plane (tên tuỳ distro)
kubectl get pods -n kube-system | grep -E 'apiserver|etcd|scheduler|controller'

# kubeadm: control plane chạy static pod trong kube-system
kubectl get pods -n kube-system
sudo systemctl status kubelet   # trên cp-1
```

---

## Đọc tiếp

- [../01-tong-quan-kien-truc.md](../01-tong-quan-kien-truc.md)
- [../node/README.md](../node/README.md) — phía worker thực thi quyết định của control plane

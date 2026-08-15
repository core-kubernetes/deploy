# Kiến trúc hiện tại

```text
Internet
    │
    │ HTTPS (be.emiu.site)
    ▼
┌──────────────────────────────────────────────────────────────┐
│                Kubernetes Cluster (AWS)                      │
│                                                              │
│  cp-1 (Control Plane)                                        │
│      │                                                       │
│      └── Chỉ điều khiển cluster, không chạy application      │
│                                                              │
│  worker-1                                                    │
│  ├── ingress-nginx (điểm vào duy nhất)                       │
│  ├── learn-api Pod #1                                        │
│  └── learn-api Pod #2                                        │
│                                                              │
│  worker-2                                                    │
│  └── learn-api Pod #3                                        │
│                                                              │
│  Namespace: learn-k8s                                        │
│                                                              │
│  Ingress (learn-api)                                         │
│      │                                                       │
│      ▼                                                       │
│  Service (learn-api)                                         │
│      ├── Type: ClusterIP                                     │
│      └── Port: 30080                                         │
│      │                                                       │
│      ▼                                                       │
│  Pod #1   Pod #2   Pod #3                                    │
│                                                              │
│  Namespace: findsource                                       │
│  ├── API: ❌ Deleted                                          │
│  ├── MySQL: ❌ Deleted                                        │
│  └── Ingress vẫn còn nhưng không có Service                  │
│      → Truy cập sẽ trả về HTTP 503                           │
└──────────────────────────────────────────────────────────────┘
```

---

# Luồng của một request

```text
Internet
    │
    ▼
DNS (be.emiu.site → 13.238.15.194)
    │
    ▼
Ingress NGINX (worker-1)
    │
    ▼
Service learn-api
    │
    ▼
Load Balancing (Round Robin)
    ├── Pod #1 (worker-1)
    ├── Pod #2 (worker-1)
    └── Pod #3 (worker-2)
```

---

# Kiểm tra hệ thống

## 1. Test qua domain (Production)

```bash
curl https://be.emiu.site/
```

Gọi nhiều lần để kiểm tra request được phân phối đến các Pod khác nhau.

```bash
for i in $(seq 1 10); do
    curl -s https://be.emiu.site/ | grep -o '"pod":"[^"]*"'
done
```

Nếu kết quả thay đổi giữa các Pod nghĩa là Service đang load balancing.

---

## 2. Test trực tiếp qua NodePort

```bash
curl http://localhost:30080/
```

---

## 3. Test Self Healing

SSH vào Control Plane:

```bash
ssh -i aws/control-plan-1.pem ubuntu@52.64.229.174
```

Xóa một Pod đang chạy:

```bash
kubectl delete pod \
    -n learn-k8s \
    -l app=learn-api \
    --field-selector=status.phase=Running \
    -o name \
| head -1 \
| xargs kubectl delete -n learn-k8s
```

Theo dõi Kubernetes tự tạo Pod mới:

```bash
kubectl get pods -n learn-k8s -w
```

---

## 4. Test Scale

Giảm xuống còn 1 Pod:

```bash
kubectl scale deployment learn-api \
    -n learn-k8s \
    --replicas=1
```

Kiểm tra:

```bash
curl https://be.emiu.site/
```

Tăng trở lại 3 Pod:

```bash
kubectl scale deployment learn-api \
    -n learn-k8s \
    --replicas=3
```

---

## 5. Kiểm tra Endpoints của Service

```bash
kubectl get endpoints learn-api -n learn-k8s
```

Kết quả sẽ hiển thị 3 địa chỉ IP nội bộ tương ứng với 3 Pod đang nhận traffic.

---

# Tổng quan

| Thành phần    | Vai trò                                |
| ------------- | -------------------------------------- |
| DNS           | Trỏ `be.emiu.site` tới IP của worker-1 |
| Ingress NGINX | Nhận toàn bộ request từ Internet       |
| Service       | Load balancing giữa các Pod            |
| Deployment    | Quản lý số lượng Pod                   |
| Pod           | Chạy ứng dụng `learn-api`              |
| Control Plane | Điều khiển Kubernetes                  |
| Worker Node   | Chạy Pod                               |

---

# Tính năng đang có

- ✅ HTTPS (Let's Encrypt)
- ✅ Ingress NGINX
- ✅ Kubernetes Deployment
- ✅ Service Load Balancing
- ✅ 3 Replica Pods
- ✅ Self Healing
- ✅ Scale Up / Scale Down
- ✅ Multi-node Cluster (1 Control Plane + 2 Worker)
- ✅ Namespace tách biệt

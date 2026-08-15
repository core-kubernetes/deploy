# Learn K8s Lab — learn-api

Lab học Kubernetes thực tế, tách biệt hoàn toàn với production (`findsource`) bằng namespace riêng — chạy chung 1 cluster, không tốn thêm server.

## Kiến trúc

```
Internet
   │
   │  https://be.emiu.site  (SSL Let's Encrypt, dùng chung cert cũ)
   ▼
┌──────────────────────────────────────────────────────────┐
│  3 server AWS = 3 node Kubernetes (1 cluster)               │
│                                                              │
│  cp-1 (control-plane)     — chỉ điều khiển, không chạy app  │
│  worker-1 ─────────────── ingress-nginx (cổng vào duy nhất) │
│    ├─ learn-api pod #1                                      │
│    └─ learn-api pod #2                                      │
│  worker-2                                                    │
│    └─ learn-api pod #3                                      │
│                                                              │
│  namespace: learn-k8s                                       │
│    Ingress "learn-api"  → Service "learn-api" (NodePort 30080)
│                         → 3 pod (round-robin load balance)  │
│                                                              │
│  namespace: findsource  → TRỐNG (api/mysql cũ đã xoá)       │
│    Ingress "findsource" vẫn còn (emiu.site/www/admin)       │
│    nhưng chưa có service phía sau → 503 nếu gọi             │
└──────────────────────────────────────────────────────────┘
```

**Đường đi 1 request tới `be.emiu.site`:**
`Internet → DNS (13.238.15.194 = public IP worker-1) → ingress-nginx (worker-1) → Service learn-api → 1 trong 3 pod (worker-1 hoặc worker-2, chọn ngẫu nhiên)`

## Thành phần

| File | Vai trò |
|---|---|
| [app/server.js](./app/server.js) | Express.js, trả về pod/node đang xử lý request — để quan sát load balancing |
| [app/Dockerfile](./app/Dockerfile) | Build image `ghcr.io/phamtuankhoi/learn-api` |
| [k8s/namespace.yaml](./k8s/namespace.yaml) | Namespace `learn-k8s` |
| [k8s/deployment.yaml](./k8s/deployment.yaml) | Deployment 3 replicas |
| [k8s/service.yaml](./k8s/service.yaml) | Service NodePort `30080` |
| [k8s/ingress.yaml](./k8s/ingress.yaml) | Ingress trỏ domain `be.emiu.site` → Service |

Secret `ghcr-secret` (pull image) và `learn-tls` (cert SSL, copy từ `findsource-tls`) đã tạo sẵn trong namespace `learn-k8s` trên cluster — không có trong repo (không commit secret).

## Cách test

**1. Gọi qua domain thật — xem load balancing:**
```bash
curl https://be.emiu.site/
for i in $(seq 1 10); do curl -s https://be.emiu.site/ | grep -o '"pod":"[^"]*"'; done
```

**2. Gọi trực tiếp không qua domain (qua SSH tunnel, không cần mở Security Group):**
```bash
ssh -i ../../aws/control-plan-1.pem -N -L 30080:localhost:30080 ubuntu@52.64.229.174 &
curl http://localhost:30080/
```

**3. Self-healing — xoá pod, xem tự dựng lại:**
```bash
ssh -i ../../aws/control-plan-1.pem ubuntu@52.64.229.174
kubectl delete pod -n learn-k8s -l app=learn-api --field-selector=status.phase=Running -o name | head -1 | xargs kubectl delete -n learn-k8s
kubectl get pods -n learn-k8s -w
```
→ Field `requestCountOnThisPod` reset về 1 ở pod mới = bằng chứng pod bị tạo lại từ đầu, không phải hồi sinh pod cũ.

**4. Scale:**
```bash
kubectl scale deployment learn-api -n learn-k8s --replicas=1   # giảm còn 1 — gọi domain nhiều lần, luôn 1 pod trả lời
kubectl scale deployment learn-api -n learn-k8s --replicas=5   # tăng lên 5
```

**5. Xem danh sách pod đang được Service chia tải (endpoints):**
```bash
kubectl get endpoints learn-api -n learn-k8s
```

## Build & deploy lại (sau khi sửa code)

```bash
# Mac
cd app
set -a && source ../../.env.ghcr && set +a
echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
docker build --platform linux/amd64 -t ghcr.io/phamtuankhoi/learn-api:latest .
docker push ghcr.io/phamtuankhoi/learn-api:latest

# cp-1 — pull lại image mới
ssh -i ../aws/control-plan-1.pem ubuntu@52.64.229.174
kubectl rollout restart deployment learn-api -n learn-k8s
kubectl rollout status deployment learn-api -n learn-k8s
```

## Dọn dẹp khi học xong

```bash
kubectl delete namespace learn-k8s
```
Xoá toàn bộ lab (pod, service, ingress, secret) — không ảnh hưởng gì tới `findsource`.

## Lịch sử — vì sao có lab này

Production backend cũ (NestJS `api` + MySQL) đã bị **xoá hẳn** khỏi namespace `findsource` (có backup SQL tại [../backups/findsource-backup-20260801.sql](../backups/findsource-backup-20260801.sql)) để tập trung học Kubernetes với 1 app đơn giản, không DB, ít nhiễu. Domain `be.emiu.site` được trỏ từ Ingress cũ (`findsource`) sang Ingress mới (`learn-api`, namespace `learn-k8s`), dùng lại cert SSL đã cấp trước đó.

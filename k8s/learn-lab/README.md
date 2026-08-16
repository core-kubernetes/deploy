# learn-api — app trên nền Kubernetes

Bắt đầu như 1 lab học Kubernetes, đang phát triển tiếp thành app thật (không chỉ để test/demo). Chạy chung cluster với hạ tầng chính (namespace riêng `learn-k8s`), dùng domain **`be.emiu.site`**.

> Yêu cầu trước khi làm file này: đã xong Bước 1-9 trong [../GETTING-STARTED.md](../GETTING-STARTED.md) — cluster 4 node Ready, ingress-nginx + cert-manager + ClusterIssuer đã cài.

## Kiến trúc

```
Internet
   │
   │  https://be.emiu.site  (SSL Let's Encrypt, tự cấp riêng cho app này)
   ▼
┌──────────────────────────────────────────────────────────┐
│  4 server AWS = 4 node Kubernetes (1 cluster)               │
│                                                              │
│  cp-1 (control-plane)     — chỉ điều khiển, không chạy app  │
│  worker-1 ─────────────── ingress-nginx (cổng vào duy nhất) │
│  worker-1, worker-2, worker-3 — mỗi node 1 pod learn-api    │
│    (topologySpreadConstraints ép trải đều, không dồn 1 node)│
│                                                              │
│  namespace: learn-k8s                                       │
│    Ingress "learn-api"  → Service "learn-api" (port 80)     │
│                         → 3 pod (round-robin load balance)  │
└──────────────────────────────────────────────────────────┘
```

**Đường đi 1 request tới `be.emiu.site`:**
`Internet → DNS (public IP worker-1, xem terraform output elastic_ips) → ingress-nginx (worker-1) → Service learn-api → 1 trong 3 pod (worker-1/2/3)`

## Thành phần

| File | Vai trò |
|---|---|
| [app/server.js](./app/server.js) | Express.js — logic app |
| [app/Dockerfile](./app/Dockerfile) | Build image `ghcr.io/phamtuankhoi/learn-api` |
| [k8s/namespace.yaml](./k8s/namespace.yaml) | Namespace `learn-k8s` |
| [k8s/deployment.yaml](./k8s/deployment.yaml) | Deployment 3 replicas, trải đều 3 worker |
| [k8s/service.yaml](./k8s/service.yaml) | Service NodePort `30080` (dự phòng test trực tiếp, không bắt buộc dùng) |
| [k8s/ingress.yaml](./k8s/ingress.yaml) | Ingress trỏ domain `be.emiu.site` → Service, tự xin SSL qua cert-manager |

Secret `ghcr-secret` (pull image từ GHCR) — **không có trong repo**, phải tự tạo (xem bên dưới), không commit secret lên Git.

---

## Deploy lần đầu (cluster trống, chưa có gì trong namespace `learn-k8s`)

**1. Build + push image** (trên laptop — cp-1 KHÔNG chạy container nên không cần code app, chỉ worker node cần pull image, và worker pull thẳng từ GHCR chứ không qua cp-1):
```bash
cd k8s/learn-lab/app
docker build --platform linux/amd64 -t ghcr.io/phamtuankhoi/learn-api:latest .

cd ../../..
set -a && source k8s/.env.ghcr && set +a
echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
docker push ghcr.io/phamtuankhoi/learn-api:latest
```
Bỏ qua bước này nếu image cũ trên GHCR còn dùng được — image KHÔNG bị xoá khi cluster bị relaunch, chỉ có k8s/cluster mất, container registry (GHCR) vẫn còn.

**2. Đảm bảo cp-1 có đủ manifest + credential** — **luôn dùng đúng path gốc `learn-lab/k8s/`, không đổi tên thư mục** (tránh lệch path giữa các cách lấy code khác nhau):

- Nếu cp-1 đã `git clone` cả repo (theo Bước 2 trong [../GETTING-STARTED.md](../GETTING-STARTED.md)) → file đã có sẵn ở đúng `~/deploy/k8s/learn-lab/k8s/`, chỉ cần `git pull` nếu code trên laptop mới sửa. Kiểm tra: `ls ~/deploy/k8s/learn-lab/k8s/`.
- Nếu cp-1 chưa có repo, copy riêng bằng scp (chạy trên laptop, **giữ nguyên cấu trúc thư mục**, không đổi tên đích):
  ```bash
  scp -i aws/cp.pem -r k8s/learn-lab ubuntu@<IP-public-cp-1>:~/deploy/k8s/
  ```

Riêng `.env.ghcr` — **luôn phải scp riêng dù dùng cách nào**, vì bị `.gitignore` không nằm trong git clone:
```bash
scp -i aws/cp.pem k8s/.env.ghcr ubuntu@<IP-public-cp-1>:~/deploy/k8s/
```
IP lấy từ `cd aws/terraform && terraform output elastic_ips`.

**3. Trên cp-1 — tạo namespace, tạo secret pull image, deploy:**
```bash
cd ~/deploy/k8s
kubectl apply -f learn-lab/k8s/namespace.yaml
NAMESPACE=learn-k8s bash scripts/05b-create-ghcr-secret.sh
kubectl apply -f learn-lab/k8s/deployment.yaml -f learn-lab/k8s/service.yaml -f learn-lab/k8s/ingress.yaml
```

**4. Kiểm tra pod trải đều 3 worker:**
```bash
kubectl get pods -n learn-k8s -o wide
```
Phải thấy 3 pod, **mỗi pod 1 node khác nhau** (worker-1, worker-2, worker-3) — nhờ `topologySpreadConstraints` trong `deployment.yaml`.

**5. Đợi SSL rồi test:**
```bash
kubectl get certificate -n learn-k8s -w
# Ctrl+C khi thấy READY=True
curl https://be.emiu.site/
```

Nếu `Certificate` không lên `READY: True` sau vài phút — xem [../errors/09-coredns-negative-cache-acme.md](../errors/09-coredns-negative-cache-acme.md) và [../errors/10-acme-order-expired.md](../errors/10-acme-order-expired.md).

---

## Cách test (sau khi đã deploy)

**1. Gọi qua domain thật — xem load balancing:**
```bash
curl https://be.emiu.site/
for i in $(seq 1 10); do curl -s https://be.emiu.site/ | grep -o '"pod":"[^"]*"'; done
```

**2. Gọi trực tiếp không qua domain** (qua SSH tunnel, không cần mở Security Group thêm):
```bash
ssh -i aws/cp.pem -N -L 30080:localhost:30080 ubuntu@<IP-public-cp-1> &
curl http://localhost:30080/
```

**3. Self-healing — xoá pod, xem tự dựng lại:**
```bash
ssh -i aws/cp.pem ubuntu@<IP-public-cp-1>
kubectl delete pod -n learn-k8s -l app=learn-api --field-selector=status.phase=Running -o name | head -1 | xargs kubectl delete -n learn-k8s
kubectl get pods -n learn-k8s -w
```
→ Field `requestCountOnThisPod` reset về 1 ở pod mới = bằng chứng pod bị tạo lại từ đầu.

**4. Scale:**
```bash
kubectl scale deployment learn-api -n learn-k8s --replicas=1
kubectl scale deployment learn-api -n learn-k8s --replicas=5
```

**5. Xem danh sách pod đang được Service chia tải (endpoints):**
```bash
kubectl get endpoints learn-api -n learn-k8s
```

---

## Deploy lại sau khi sửa code

```bash
# Mac
cd k8s/learn-lab/app
docker build --platform linux/amd64 -t ghcr.io/phamtuankhoi/learn-api:latest .
cd ../../..
set -a && source k8s/.env.ghcr && set +a
echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
docker push ghcr.io/phamtuankhoi/learn-api:latest

# cp-1 — pull lại image mới, rolling update (không downtime)
ssh -i aws/cp.pem ubuntu@<IP-public-cp-1>
kubectl rollout restart deployment learn-api -n learn-k8s
kubectl rollout status deployment learn-api -n learn-k8s
```

---

## Dọn dẹp (nếu cần xoá hẳn để làm lại từ đầu)

```bash
kubectl delete namespace learn-k8s
```
Xoá toàn bộ (pod, service, ingress, secret). Certificate SSL cũng mất, lần deploy sau phải xin lại từ đầu (mất vài phút, không tốn phí).

---

## Ghi chú — hướng phát triển

App này **không còn là lab thuần tuý** — đang dùng làm nền để phát triển thành app thật, không phải chỉ demo/test rồi bỏ. Khi thêm tính năng thật, cân nhắc sớm (đỡ phải làm lại sau):

- **CI/CD** — hiện vẫn deploy tay, nên tách riêng pipeline khi code ổn định hơn
- **Database/state** — hiện app không lưu gì (stateless) — nếu cần lưu dữ liệu thật, phải thêm PVC/StatefulSet (khác hẳn Deployment thường, xem [concepts/01-workload-objects.md](./concepts/01-workload-objects.md) mục PVC/StatefulSet)
- **Resource limits** hiện đang ở mức lab (50m-200m CPU, 64-128Mi RAM) — cần đo lại theo tải thật khi có traffic thật
- **Giám sát/backup tự động** — chưa có, xem đánh giá đầy đủ đã trao đổi trong lịch sử chat (Prometheus/Grafana, CronJob backup...) trước khi coi đây là "production thật"

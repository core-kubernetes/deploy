# Bắt đầu ngay — làm trước, học sau

Làm theo checklist này **từ trên xuống**. Mỗi bước có **Checkpoint** — chưa pass thì không xuống bước dưới.

Domain: **emiu.site** · Cluster: **kubeadm** (cp-1 + worker-1 + worker-2)

**Tiến độ deploy (đọc khi quay lại):** [`DEPLOY-STATUS.md`](./DEPLOY-STATUS.md)

> ⚠️ **Trạng thái thật hiện tại (đọc trước khi làm gì):** cluster 3 node vẫn chạy, nhưng **backend production (NestJS `api` + `mysql`) đã bị xoá hẳn** khỏi namespace `findsource` (có backup SQL tại `k8s/backups/`) để dành cluster học Kubernetes (namespace `learn-k8s`, xem [learn-lab/README.md](./learn-lab/README.md)). Domain **`be.emiu.site` hiện đang trỏ vào lab học (`learn-api`)**, không phải backend thật. Muốn deploy lại production thật — làm theo checklist bên dưới **và thêm bước dọn domain** ở cuối file: [Khôi phục production sau khi dùng chung cluster với lab học](#khôi-phục-production-sau-khi-dùng-chung-cluster-với-lab-học).

---

## Bạn cần có trước

- [ ] 3 VPS Ubuntu 22.04 (cp-1: 2C4G · worker-1/2: 4C8G)
- [ ] SSH key, user **`ubuntu`** có sudo
- [ ] Domain **emiu.site** (DNS cấu hình ở Bước 8)
- [ ] Thư mục `~/deploy/k8s` trên cp-1 (git clone hoặc scp)

---

## Bước 1 — SSH và đặt tên (15 phút)

Trên **từng server**:

```bash
# cp-1
sudo hostnamectl set-hostname cp-1

# worker-1
sudo hostnamectl set-hostname worker-1

# worker-2
sudo hostnamectl set-hostname worker-2
```

Sửa `/etc/hosts` trên **cả 3** (thay IP thật):

```
<IP_cp-1>    cp-1
<IP_worker-1> worker-1
<IP_worker-2> worker-2
52.64.229.174 cp-1
13.238.15.194 worker-1
13.54.216.178 worker-2
```

**Checkpoint:** `hostname` trả đúng tên trên mỗi máy.

---

## Bước 2 — Copy repo lên server (10 phút)

Trên **cả 3 node** (hoặc git clone):

```bash
# Ví dụ clone monorepo / copy thư mục deploy
mkdir -p ~/deploy
# scp -r deploy/ devops@<IP>:~/deploy   # từ laptop
```

Hoặc trên laptop push GitHub, trên server:

```bash
git clone <repo-url> ~/deploy-repo && ln -s ~/deploy-repo/deploy ~/deploy   # hoac scp thang deploy/ len ~/deploy
```

**Checkpoint:** Có file `~/deploy/k8s/kubeadm/01-prerequisites-all-nodes.sh`

---

## Bước 3 — Cài nền + kubeadm (cả 3 node, 20 phút)

Trên **cp-1, worker-1, worker-2** (lần lượt SSH từng máy):

```bash
cd ~/deploy/k8s/kubeadm
sudo bash 01-prerequisites-all-nodes.sh
sudo bash 02-install-containerd-kubeadm.sh
```

**Checkpoint:** `kubeadm version` và `containerd --version` chạy được trên cả 3.

---

## Bước 4 — Init Control Plane (chỉ cp-1, 10 phút)

Chỉ SSH vào **cp-1**:

```bash
cd ~/deploy/k8s/kubeadm
# Cách 1: truyền IP (khuyến nghị — IP private trong VPC nếu worker cùng mạng)
sudo bash 03-init-control-plane.sh <IP_cp-1>

# Cách 2: script tự lấy IP đầu tiên của hostname -I
sudo bash 03-init-control-plane.sh
```

**Lưu lệnh `kubeadm join ...`** in ra cuối — dùng trên **worker-1** và **worker-2** để 2 máy đó “xin vào” cluster (chưa join thì chỉ có cp-1, app không chạy được trên worker).

```text
kubeadm join 172.31.30.134:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

- Chạy **trên từng worker** (SSH worker-1, rồi worker-2), với `sudo`.
- IP `172.31.30.134` = private IP cp-1 (đúng với AWS cùng VPC).
- Token hết hạn sau ~24h → trên cp-1: `kubeadm token create --print-join-command`

Thiết lập kubectl (user devops, vẫn trên cp-1):

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

**Checkpoint:** Thấy `cp-1` status `NotReady` (bình thường — chưa có CNI).

---

## Bước 5 — Flannel CNI (cp-1, 5 phút)

```bash
cd ~/deploy/k8s/kubeadm
bash 05-install-cni-flannel.sh
kubectl get nodes
```

**Checkpoint:** `cp-1` → **Ready**.

---

## Bước 6 — Join worker (worker-1 & worker-2, 10 phút)

### Token và `sha256:...` lấy ở đâu?

Cả hai do **`kubeadm init` trên cp-1 tạo ra** — bạn **không tự nghĩ** ra.

| Thành phần                                  | Ví dụ                     | Ý nghĩa                                                               |
| ------------------------------------------- | ------------------------- | --------------------------------------------------------------------- |
| `172.31.30.134:6443`                        | IP private cp-1           | Địa chỉ API Server (cùng IP đã dùng trong `03-init-control-plane.sh`) |
| `--token abc.def`                           | `91drif.rhe27wpia6l1tvqx` | Mật khẩu tạm để worker đăng ký (bootstrap token)                      |
| `--discovery-token-ca-cert-hash sha256:...` | `sha256:350fd38d...`      | Hash cert cluster — chống join nhầm cluster giả                       |

**Nguồn lệnh đầy đủ (chọn 1):**

1. **Cuối output `03-init-control-plane.sh`** — 2 dòng `kubeadm join ...` (dùng **dòng cuối**, token mới hơn).
2. **Bất cứ lúc nào trên cp-1** (token cũ hết hạn sau ~24h):

```bash
# Trên cp-1 — in ra 1 dòng copy-paste
kubeadm token create --print-join-command
```

Ví dụ output:

```text
kubeadm join 172.31.30.134:6443 --token 91drif.rhe27wpia6l1tvqx \
  --discovery-token-ca-cert-hash sha256:350fd38d37032b089397ee4824cf8d96a304fb208a4a768724118ecc77fb563e
```

→ Copy **nguyên cả dòng** (gộp 1 dòng cũng được).

---

### Chạy trên worker-1, rồi worker-2

**Cách A — trực tiếp (dễ nhất):**

```bash
sudo kubeadm join 172.31.30.134:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Thay `<TOKEN>` và `<HASH>` bằng giá trị từ lệnh trên cp-1.

**Cách B — script:**

```bash
cd ~/deploy/k8s/kubeadm
sudo bash 04-join-worker.sh 'kubeadm join 172.31.30.134:6443 --token 91drif.rhe27wpia6l1tvqx --discovery-token-ca-cert-hash sha256:350fd38d37032b089397ee4824cf8d96a304fb208a4a768724118ecc77fb563e'
```

(Dán **đúng** lệnh của bạn — ví dụ trên chỉ là mẫu.)

**Checkpoint trên worker:** thấy `This node has joined the cluster.`

Lặp lại trên **worker-2** (cùng lệnh join).

**Lỗi `context deadline exceeded` khi join (AWS):** worker không tới `cp-1:6443` → xem [errors/03-join-timeout-aws-security-group.md](./errors/03-join-timeout-aws-security-group.md). Test: `nc -zv 172.31.30.134 6443`.

Quay lại **cp-1**:

```bash
kubectl get nodes -o wide
```

**Checkpoint:**

```
cp-1       Ready   control-plane
worker-1   Ready   <none>
worker-2   Ready   <none>
```

→ **Cluster xong.** Học lý thuyết sau — bạn đã có K8s thật.

---

## Bước 7 — SSH cp-1 (chuẩn bị deploy)

**Mọi lệnh `kubectl` từ Bước 9 trở đi chạy trên cp-1** — không cần copy kubeconfig về laptop (API dùng IP private `172.31.x.x`, Mac sẽ timeout).

Trên **laptop**:

```bash
ssh -i control-plan-1.pem ubuntu@52.64.229.174
```

Trên **cp-1** (kubectl đã setup ở Bước 4):

```bash
kubectl get nodes -o wide
```

**Checkpoint:** Thấy cp-1, worker-1, worker-2 đều **Ready**.

**Tuỳ chọn — kubectl trên laptop:** dùng SSH tunnel — [errors/04-kubectl-timeout-laptop-private-ip.md](./errors/04-kubectl-timeout-laptop-private-ip.md).

---

## Bước 8 — DNS emiu.site (5 phút)

Tại nhà cung cấp domain, A record → **public IP worker-1** (Ingress nhận traffic ở đây):

| IP              | Dùng cho DNS? | Ghi chú                                                   |
| --------------- | ------------- | --------------------------------------------------------- |
| `13.238.15.194` | **Có**        | Public IP — user trên internet truy cập được              |
| `172.31.23.25`  | **Không**     | Private IP trong VPC — chỉ node trong cluster dùng nội bộ |

| Name  | Type | Value           |
| ----- | ---- | --------------- |
| @     | A    | `13.238.15.194` |
| www   | A    | `13.238.15.194` |
| be    | A    | `13.238.15.194` |
| admin | A    | `13.238.15.194` |

Mở SG **worker-1**: Inbound **TCP 80, 443** từ `0.0.0.0/0`.

Kiểm tra (laptop hoặc cp-1):

```bash
dig +short emiu.site A
```

**Checkpoint:** DNS trả `13.238.15.194` (chờ 5–30 phút nếu mới tạo).

⚠️ **Thêm CẢ 4 record (`@`, `www`, `be`, `admin`) CÙNG LÚC.** Certificate ở Bước 9 xin SSL cho cả 4 domain trong 1 lần (multi-SAN) — chỉ issue khi **cả 4** xác thực được. Thêm thiếu 1 record rồi thêm bù sau **không tự động retry sạch** — xem cảnh báo CoreDNS cache ở Bước 9.

---

## Bước 9 — Ingress + SSL (trên cp-1, 15 phút)

SSH vào cp-1:

```bash
cd ~/deploy/k8s
nano base/cert-manager/cluster-issuer.yaml   # sửa email nếu cần
bash scripts/04-install-addons.sh
kubectl apply -f base/cert-manager/cluster-issuer.yaml
```

### Vì sao cấu hình đặc biệt (EC2 kubeadm)?

| Cấu hình                 | Lý do                                                                  |
| ------------------------ | ---------------------------------------------------------------------- |
| `hostNetwork: true`      | Bind thẳng port **80/443** trên node — EC2 không có cloud LoadBalancer |
| `nodeSelector: worker-1` | DNS A record trỏ **public IP worker-1** — traffic phải vào đúng node   |
| Tắt admission webhook    | Tránh Helm timeout / job `admission-*` trên cluster nhỏ                |

Script `04-install-addons.sh` đã set sẵn các giá trị trên.

### Checkpoint — Ingress OK

```bash
kubectl get pods -n ingress-nginx -o wide
```

Phải thấy:

```text
NAME                          READY   STATUS    NODE       IP
ingress-nginx-controller-...  1/1     Running   worker-1   172.31.23.25
```

- **NODE = `worker-1`** (không phải worker-2 hay cp-1)
- **IP = private IP worker-1** (`172.31.23.25`) — **không** phải `10.244.x.x` (nếu thấy `10.244.x.x` = chưa bật hostNetwork)

Kiểm tra port 80/443 **từ cp-1** (không cần SSH worker — file `.pem` chỉ có trên Mac):

```bash
# Cách 1 — curl public IP worker-1
curl -I http://13.238.15.194

# Cách 2 — exec vào pod ingress
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- ss -tlnp | grep ':80\|:443'
```

**Lưu ý:** `sudo ss ...` trên **cp-1** không thấy port 80 — bình thường, vì nginx chạy trên **worker-1**.

Lỗi Helm `context deadline exceeded`: [errors/05-helm-ingress-timeout.md](./errors/05-helm-ingress-timeout.md)

### Checkpoint — cert-manager OK

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer letsencrypt-prod
```

Pod `cert-manager`, `cert-manager-webhook`, `cert-manager-cainjector` → **Running**.

Helm báo `failed post-install` / pod `startupapicheck` Error — **bỏ qua** nếu 3 pod trên Running. Chi tiết: [errors/06-cert-manager-startupapicheck.md](./errors/06-cert-manager-startupapicheck.md)

```bash
kubectl apply -f base/cert-manager/cluster-issuer.yaml
kubectl get clusterissuer letsencrypt-prod
```

### Checkpoint — Certificate thật sự Ready (không phải fake cert)

```bash
kubectl get certificate -n findsource
# findsource-tls   READY=True   ← phải là True, không phải False
```

Nếu **`READY: False` quá vài phút**, kiểm tra từng domain:

```bash
kubectl get challenge -n findsource
```

- Domain nào `state: pending` mãi → DNS domain đó **chưa resolve được từ BÊN TRONG cluster** (khác với resolve được từ laptop!). Test đúng cách:
  ```bash
  kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup <domain>
  ```
  Nếu `SERVFAIL` dù DNS ngoài đã đúng (`dig` từ laptop ra kết quả tốt) → **CoreDNS đang cache kết quả lỗi cũ** (thường xảy ra khi record DNS được thêm **trễ**, sau khi cert-manager đã thử và fail vài lần). Fix: `kubectl rollout restart deployment coredns -n kube-system`, đợi ~10s, test lại `nslookup`.
- Nếu challenge ở trạng thái **`expired`** (thường sau khi bị pending quá lâu, > vài chục phút tới vài giờ tuỳ ACME server) → order cũ **không tự retry được nữa**, phải tạo lại từ đầu:
  ```bash
  kubectl delete certificate findsource-tls -n findsource
  kubectl apply -f base/cert-manager/cluster-issuer.yaml   # (không bắt buộc, issuer không đổi)
  kubectl apply -k overlays/production   # ingress-shim sẽ tự tạo lại Certificate mới từ Ingress
  ```
  Chi tiết đầy đủ: [errors/09-coredns-negative-cache-acme.md](./errors/09-coredns-negative-cache-acme.md) và [errors/10-acme-order-expired.md](./errors/10-acme-order-expired.md)

## Bước 10 — Secret + deploy app (trên cp-1, 30 phút)

Trên cp-1 — làm ngay
.env.ghcr không lên git — copy bằng scp từ Mac:
scp -i "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws/control-plan-1.pem" \
 "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/k8s/.env.ghcr" \
 ubuntu@52.64.229.174:~/deploy/k8s/

Trên cp-1:

```bash
cd ~/deploy/k8s
cp .env.production.example .env.production
# Sửa: password MySQL, JWT secret, v.v.
nano .env.production

bash scripts/05-create-secrets.sh
```

Image GHCR: `ghcr.io/phamtuankhoi/...` (đã set trong `overlays/`). Credential: [GHCR.md](./GHCR.md) + file `.env.ghcr`.

Build image lần đầu trên laptop (Bước 11), rồi trên **cp-1**:

```bash
kubectl apply -k overlays/production
kubectl get pods -n findsource -w
```

**Checkpoint:** Pod `api`, `web`, `admin`, `mysql` → **Running**.

```bash
curl -I http://be.emiu.site/process    # trước SSL
curl -I https://be.emiu.site/process   # sau cert Ready (~2 phút)
```

---

## Bước 11 — Image lần đầu (chưa cần CI)

Chi tiết + credential: **[GHCR.md](./GHCR.md)** (file `.env.ghcr`, user `PhamTuanKhoi`, image `ghcr.io/phamtuankhoi`).

**Mac:**

```bash
cd deploy/k8s && set -a && source .env.ghcr && set +a
echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
export GHCR_USER=phamtuankhoi

cd findsource-be
docker build -t ghcr.io/$GHCR_USER/findsource-api:production .
docker push ghcr.io/$GHCR_USER/findsource-api:production
```

**cp-1** (copy `.env.ghcr` lên server hoặc tạo tay):

```bash
cd ~/deploy/k8s
bash scripts/05b-create-ghcr-secret.sh
bash scripts/08-deploy-be.sh          # mysql + api trước
# kubectl apply -k overlays/production   # sau khi push đủ web/admin
```

CI/CD (`deploy-k8s.yml`) làm **sau** khi site chạy được tay.

⚠️ **GHCR token (`GITHUB_PAT`) có thể bị GitHub thu hồi TRƯỚC ngày hết hạn** (secret scanning tự phát hiện token lộ, hoặc bị revoke thủ công) — pod chạy ổn định nhiều ngày/tuần **không có nghĩa token còn dùng được**, vì image đã cache sẵn trên node không cần pull lại. Token chỉ thật sự bị kiểm tra lại khi node reboot / pod bị xoá và phải pull image lần nữa.

**Triệu chứng:** pod đã Running lâu ngày bỗng `ImagePullBackOff` sau khi node restart hoặc pod bị xoá, log có `403 Forbidden` khi pull GHCR. Cách kiểm tra token còn dùng được không:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -u "$GITHUB_USER:$GITHUB_PAT" https://api.github.com/user
# 200 = token OK · 401 = token bị revoke, cần tạo token mới
```

Fix: tạo PAT mới (scope `read:packages`) tại github.com/settings/tokens → sửa `.env.ghcr` → chạy lại `scripts/05b-create-ghcr-secret.sh` → `kubectl delete pod -n findsource -l app=api` để pod pull lại bằng token mới. Chi tiết: [errors/08-ghcr-token-revoked.md](./errors/08-ghcr-token-revoked.md)

---

## Không làm gì lúc này

| Việc                          | Khi nào                 |
| ----------------------------- | ----------------------- |
| Đọc hết study-kubernetes      | Sau Bước 6              |
| Tạo GitHub self-hosted runner | Sau site chạy (Bước 10) |
| CI/CD GitHub Actions          | Sau deploy tay OK       |
| HA 3 Control Plane            | Học xong vài tuần       |

---

## Kẹt ở đâu?

Xem **[errors/README.md](./errors/README.md)** — log lỗi thực tế + fix.

| Triệu chứng              | File                                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------- |
| `NODE_IP` / init fail    | [01-node-ip-not-set.md](./errors/01-node-ip-not-set.md)                                     |
| `conntrack not found`    | [02-conntrack-not-found.md](./errors/02-conntrack-not-found.md)                             |
| join timeout / `nc` 6443 | [03-join-timeout-aws-security-group.md](./errors/03-join-timeout-aws-security-group.md)     |
| laptop `kubectl` timeout | [04-kubectl-timeout-laptop-private-ip.md](./errors/04-kubectl-timeout-laptop-private-ip.md) |
| Helm ingress timeout     | [05-helm-ingress-timeout.md](./errors/05-helm-ingress-timeout.md)                           |
| Node NotReady mãi        | Chưa Flannel (Bước 5)                                                                       |
| PVC Pending               | [07-pvc-no-storageclass.md](./errors/07-pvc-no-storageclass.md)                             |
| Pod ImagePullBackOff (lần đầu deploy) | Chưa GHCR / ghcr-secret                                                        |
| Pod chạy lâu ngày bỗng ImagePullBackOff | [08-ghcr-token-revoked.md](./errors/08-ghcr-token-revoked.md) — token bị revoke |
| SSL fail — DNS đúng ngoài nhưng SERVFAIL trong cluster | [09-coredns-negative-cache-acme.md](./errors/09-coredns-negative-cache-acme.md) |
| SSL fail — Certificate không issue dù DNS đã đúng | [10-acme-order-expired.md](./errors/10-acme-order-expired.md)                  |

---

---

## Tiếp theo (sau Bước 9 Ingress OK)

Ingress đã **Running** trên `worker-1` với IP `172.31.23.25` → làm **Bước 10**:

```bash
# cp-1
cd ~/deploy/k8s
kubectl get pods -n cert-manager          # chưa có → chạy phần cert-manager trong script hoặc script lại
kubectl apply -f base/cert-manager/cluster-issuer.yaml

cp .env.production.example .env.production
nano .env.production
bash scripts/05-create-secrets.sh
# build + push image (Bước 11) rồi:
kubectl apply -k overlays/production
```

Học sau: [`../study-kubernetes/README.md`](../study-kubernetes/README.md) · [`K8S-COMPONENTS.md`](./K8S-COMPONENTS.md)

---

## Khôi phục production sau khi dùng chung cluster với lab học

Nếu bạn đã theo [learn-lab/README.md](./learn-lab/README.md), domain `be.emiu.site` hiện **thuộc về Ingress `learn-api`** (namespace `learn-k8s`), còn Ingress `findsource` (namespace `findsource`) **không còn rule cho `be.emiu.site`** — 2 Ingress này đã cố tình swap domain cho nhau, không tự đụng nhau nhưng cũng không tự trả lại.

**Bước 1 — Lấy lại domain cho production:**

```bash
# Trên cp-1
kubectl delete ingress learn-api -n learn-k8s
```

**Bước 2 — Thêm lại rule `be.emiu.site` vào `base/ingress/ingress.yaml`** (đã bị gỡ khi làm lab — sửa trên laptop rồi scp/apply lại, hoặc `nano` trực tiếp trên cp-1):

```yaml
  tls:
    - hosts:
        - emiu.site
        - www.emiu.site
        - be.emiu.site      # ← thêm lại dòng này
        - admin.emiu.site
      secretName: findsource-tls
  rules:
    - host: be.emiu.site    # ← thêm lại cả block này
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 7003
    - host: emiu.site
      # ... (giữ nguyên phần còn lại)
```

```bash
kubectl apply -n findsource -f base/ingress/ingress.yaml
```

**Bước 3 — Deploy lại api + mysql** (đã bị xoá hoàn toàn, kể cả PVC — database sẽ **rỗng**, không tự có lại data cũ):

```bash
kubectl apply -k overlays/production
kubectl get pods -n findsource -w
```

**Bước 4 — Khôi phục dữ liệu cũ (nếu cần)** từ backup đã tạo lúc xoá:

```bash
# Copy backup lên cp-1 nếu chưa có (backup nằm ở k8s/backups/ trên laptop)
scp -i ../aws/control-plan-1.pem ../k8s/backups/findsource-backup-*.sql ubuntu@52.64.229.174:~/

# Trên cp-1 — đợi mysql-0 Running rồi mới import
PW=$(kubectl get secret findsource-mysql-env -n findsource -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d)
kubectl exec -i -n findsource mysql-0 -- env MYSQL_PWD="$PW" mysql -uroot findsource < ~/findsource-backup-*.sql
```

**Bước 5 — Xoá lab học** (nếu không cần dùng nữa, dọn sạch tài nguyên):

```bash
kubectl delete namespace learn-k8s
```

**Checkpoint:** `curl https://be.emiu.site/process` trả response thật từ NestJS API, không phải JSON `learn-api`.

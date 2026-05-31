# Bắt đầu ngay — làm trước, học sau

Làm theo checklist này **từ trên xuống**. Mỗi bước có **Checkpoint** — chưa pass thì không xuống bước dưới.

Domain: **emiu.site** · Cluster: **kubeadm** (cp-1 + worker-1 + worker-2)

---

## Bạn cần có trước

- [ ] 3 VPS Ubuntu 22.04 (cp-1: 2C4G · worker-1/2: 4C8G)
- [ ] SSH key, user `devops` có sudo
- [ ] Domain **emiu.site** (DNS cấu hình ở Bước 8)
- [ ] Laptop có `git` + `kubectl` (cài sau Bước 4)

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
mkdir -p ~/findsource
# scp -r deploy/ devops@<IP>:~/findsource/deploy   # từ laptop
```

Hoặc trên laptop push GitHub, trên server:

```bash
git clone <repo-url> ~/findsource
```

**Checkpoint:** Có file `~/findsource/deploy/k8s/kubeadm/01-prerequisites-all-nodes.sh`

---

## Bước 3 — Cài nền + kubeadm (cả 3 node, 20 phút)

Trên **cp-1, worker-1, worker-2** (lần lượt SSH từng máy):

```bash
cd ~/findsource/deploy/k8s/kubeadm
sudo bash 01-prerequisites-all-nodes.sh
sudo bash 02-install-containerd-kubeadm.sh
```

**Checkpoint:** `kubeadm version` và `containerd --version` chạy được trên cả 3.

---

## Bước 4 — Init Control Plane (chỉ cp-1, 10 phút)

Chỉ SSH vào **cp-1**:

```bash
cd ~/findsource/deploy/k8s/kubeadm
# Cách 1: truyền IP (khuyến nghị — IP private trong VPC nếu worker cùng mạng)
sudo bash 03-init-control-plane.sh <IP_cp-1>

# Cách 2: script tự lấy IP đầu tiên của hostname -I
sudo bash 03-init-control-plane.sh
```

Copy **lệnh `kubeadm join ...`** in ra cuối — lưu Notepad.

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
cd ~/findsource/deploy/k8s/kubeadm
bash 05-install-cni-flannel.sh
kubectl get nodes
```

**Checkpoint:** `cp-1` → **Ready**.

---

## Bước 6 — Join worker (worker-1 & worker-2, 10 phút)

Trên **worker-1**, rồi **worker-2**:

```bash
cd ~/findsource/deploy/k8s/kubeadm
export JOIN_CMD='kubeadm join <IP_cp-1>:6443 --token ... --discovery-token-ca-cert-hash sha256:...'
sudo -E bash 04-join-worker.sh
```

Token hết hạn? Trên cp-1:

```bash
kubeadm token create --print-join-command
```

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

## Bước 7 — Kubeconfig về laptop (5 phút)

Trên **laptop**:

```bash
scp devops@<IP_cp-1>:~/.kube/config ~/.kube/emiu-site.yaml
export KUBECONFIG=~/.kube/emiu-site.yaml
kubectl get nodes
```

**Checkpoint:** Laptop gọi được cluster.

---

## Bước 8 — DNS emiu.site (5 phút)

Tại nhà cung cấp domain, A record → IP **worker-1** (sau Ingress sẽ nhận traffic ở đây):

| Name  | Type | Value           |
| ----- | ---- | --------------- |
| @     | A    | `<IP_worker-1>` |
| www   | A    | `<IP_worker-1>` |
| be    | A    | `<IP_worker-1>` |
| admin | A    | `<IP_worker-1>` |

```bash
dig +short emiu.site A
```

**Checkpoint:** DNS trả đúng IP worker-1 (chờ 5–30 phút nếu mới tạo).

---

## Bước 9 — Ingress + SSL (cp-1 hoặc laptop, 15 phút)

```bash
export KUBECONFIG=~/.kube/emiu-site.yaml   # laptop hoặc cp-1

# Sửa email trong file trước:
# deploy/k8s/base/cert-manager/cluster-issuer.yaml

bash deploy/k8s/scripts/04-install-addons.sh
kubectl apply -f deploy/k8s/base/cert-manager/cluster-issuer.yaml
```

**Checkpoint:**

```bash
kubectl get pods -n ingress-nginx
kubectl get pods -n cert-manager
# Tất cả Running
```

---

## Bước 10 — Secret + deploy app (30 phút)

```bash
cd deploy/k8s
cp .env.production.example .env.production
# Sửa: password MySQL, JWT secret, v.v.

bash scripts/05-create-secrets.sh
```

Sửa image GitHub org trong `overlays/production/kustomization.yaml`:

```yaml
newName: ghcr.io/YOUR_GITHUB_USER/findsource-api
```

Build image lần đầu (tạm trên laptop hoặc dùng image local — xem Bước 11), rồi:

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

**Cách nhanh nhất** — build trên laptop, push GHCR:

```bash
# Login GHCR (PAT packages:write)
echo $GITHUB_PAT | docker login ghcr.io -u YOUR_USER --password-stdin

# API (từ repo findsource-be)
docker build -t ghcr.io/YOUR_USER/findsource-api:production .
docker push ghcr.io/YOUR_USER/findsource-api:production

# FE / Admin tương tự — nhớ build-arg URL emiu.site
```

Tạo pull secret trên cluster:

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USER \
  --docker-password=YOUR_PAT \
  -n findsource
```

CI/CD (`deploy-k8s.yml`) làm **sau** khi site chạy được tay.

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

| Triệu chứng          | Xem                               |
| -------------------- | --------------------------------- |
| Node NotReady mãi    | Chưa chạy Flannel (Bước 5)        |
| kubeadm join fail    | Token hết hạn, firewall 6443      |
| Pod ImagePullBackOff | Chưa push GHCR / chưa ghcr-secret |
| SSL fail             | DNS chưa trỏ, port 80 chưa mở     |

---

## Hôm nay — 3 việc duy nhất

1. **Thuê 3 VPS** + SSH được
2. **Bước 1 → 3** trên cả 3 máy
3. **Bước 4 → 6** trên cp-1 rồi join worker

Gửi output `kubectl get nodes -o wide` khi xong Bước 6.

Học sau: [`../study-kubernetes/README.md`](../study-kubernetes/README.md) · [`K8S-COMPONENTS.md`](./K8S-COMPONENTS.md)

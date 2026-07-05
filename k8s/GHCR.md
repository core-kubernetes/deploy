# GHCR — GitHub Container Registry (findsource)

Tài liệu lưu **cách làm** push image và pull trên cluster. Secret thật nằm trong **`.env.ghcr`** (gitignore, không commit).

---

## Tài khoản findsource

| Biến | Giá trị |
|------|---------|
| GitHub login | `PhamTuanKhoi` |
| GHCR image prefix | `ghcr.io/phamtuankhoi` (chữ thường) |

File secret: `deploy/k8s/.env.ghcr` (copy từ `.env.ghcr.example`).

---

## 1. Mac — login & build & push

```bash
cd deploy/k8s
set -a && source .env.ghcr && set +a

echo "$GITHUB_PAT" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

export GHCR_USER="${GHCR_USER:-$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]')}"

# API
cd ../../findsource-be
docker build -t ghcr.io/$GHCR_USER/findsource-api:production .
docker push ghcr.io/$GHCR_USER/findsource-api:production
```

Web / Admin: xem build-arg trong [GETTING-STARTED.md](./GETTING-STARTED.md) Bước 11.

**Lỗi thường gặp:**

| Lỗi | Fix |
|-----|-----|
| `docker.sock` | Mở Docker Desktop |
| `must be lowercase` | Image tag dùng `$GHCR_USER` không phải `$GITHUB_USER` |

---

## 2. cp-1 — ghcr-secret + deploy

```bash
cd ~/deploy/k8s
# Copy .env.ghcr từ Mac: scp -i control-plan-1.pem k8s/.env.ghcr ubuntu@52.64.229.174:~/deploy/k8s/

set -a && source .env.ghcr && set +a

kubectl create secret docker-registry ghcr-secret \
  --namespace=findsource \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USER" \
  --docker-password="$GITHUB_PAT" \
  --dry-run=client -o yaml | kubectl apply -f -

bash scripts/08-deploy-be.sh
```

Full stack: `kubectl apply -k overlays/production`

---

## 3. Kustomize image

Đã set `ghcr.io/phamtuankhoi` trong `overlays/production-be/` và `overlays/production/`.

---

## 4. PAT hết hạn

Sửa `GITHUB_PAT` trong `.env.ghcr` (Mac + cp-1) → login lại → tạo lại `ghcr-secret`.

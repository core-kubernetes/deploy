# Tiến độ deploy emiu.site

**Cập nhật lần cuối:** 2026-06-25  
**Làm việc trên:** cp-1 (`ssh -i control-plan-1.pem ubuntu@52.64.229.174`)  
**Doc chính:** [GETTING-STARTED.md](./GETTING-STARTED.md)

> Khi tắt Cursor / quay lại sau vài ngày: mở file này hoặc chat *"đọc DEPLOY-STATUS.md, tiếp tục deploy"*.

---

## Bước tiếp theo (làm ngay)

```bash
# Trên cp-1
cd ~/deploy/k8s
kubectl get clusterissuer letsencrypt-prod   # chưa có → apply bên dưới
kubectl apply -f base/cert-manager/cluster-issuer.yaml
```

Sau đó → **Bước 11** (build/push image GHCR trên Mac) → **Bước 10** (secret + deploy app).

---

## Checklist

| Bước | Việc | Trạng thái | Ghi chú |
|------|------|------------|---------|
| 1–3 | Hostname, repo, kubeadm prereq | ✅ | Ubuntu 26.04 |
| 4 | Init cp-1 (`172.31.30.134`) | ✅ | |
| 5 | Flannel CNI | ✅ | |
| 6 | Join worker-1, worker-2 | ✅ | 3 node Ready |
| 7 | SSH cp-1, kubectl trên cp-1 | ✅ | Không dùng kubectl laptop |
| 8 | DNS emiu.site → **13.238.15.194** | ⬜ | **Public IP worker-1** — không dùng `172.31.23.25` |
| 8b | SG worker-1: TCP 80, 443 | ⬜ | AWS Console |
| 9a | Ingress (hostNetwork + worker-1) | ✅ | Pod IP `172.31.23.25`, NODE `worker-1` |
| 9b | cert-manager | ✅ | Helm có thể báo startupapicheck — bỏ qua |
| 9c | ClusterIssuer letsencrypt-prod | ⬜ | `kubectl apply -f base/cert-manager/cluster-issuer.yaml` |
| 10 | `.env.production` + secrets | ⬜ | `scripts/05-create-secrets.sh` |
| 11 | Build/push GHCR + ghcr-secret | ⬜ | Trên Mac |
| 10b | `kubectl apply -k overlays/production` | ⬜ | Sau Bước 11 |
| — | Site https://emiu.site chạy | ⬜ | |
| — | CI/CD GitHub Actions | ⬜ | Sau deploy tay OK |

---

## Cluster (snapshot)

```
cp-1       Ready   172.31.30.134   public 52.64.229.174
worker-1   Ready   172.31.23.25    public 13.238.15.194  ← DNS + Ingress
worker-2   Ready   172.31.26.60    public 13.54.216.178
```

---

## Lệnh kiểm tra nhanh (cp-1)

```bash
kubectl get nodes -o wide
kubectl get pods -n ingress-nginx -o wide
kubectl get pods -n cert-manager
kubectl get clusterissuer
kubectl get pods -n findsource
```

---

## Lỗi đã gặp (xem chi tiết trong errors/)

| Lỗi | File |
|-----|------|
| join timeout SG | [03-join-timeout-aws-security-group.md](./errors/03-join-timeout-aws-security-group.md) |
| laptop kubectl timeout | [04-kubectl-timeout-laptop-private-ip.md](./errors/04-kubectl-timeout-laptop-private-ip.md) |
| Helm ingress timeout | [05-helm-ingress-timeout.md](./errors/05-helm-ingress-timeout.md) |
| cert-manager startupapicheck | [06-cert-manager-startupapicheck.md](./errors/06-cert-manager-startupapicheck.md) |

---

## Cách cập nhật file này

Sau mỗi bước xong, sửa cột **Trạng thái** (`⬜` → `✅`) và **Bước tiếp theo** ở đầu file.  
Hoặc nhắn Cursor: *"cập nhật DEPLOY-STATUS.md — đã xong bước X"*.

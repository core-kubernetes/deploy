# Tiến độ deploy emiu.site

**Cập nhật lần cuối:** 2026-08-01
**Làm việc trên:** cp-1 (`ssh -i aws/control-plan-1.pem ubuntu@52.64.229.174`)
**Doc chính:** [GETTING-STARTED.md](./GETTING-STARTED.md)

> Khi quay lại sau vài ngày: mở file này trước để biết chính xác trạng thái thật, đừng tin vào ký ức — cluster này bị dùng chung giữa production và lab học, trạng thái đổi liên tục.

---

## Trạng thái thật hiện tại (không phải trạng thái lý tưởng)

**Cluster hạ tầng:** ✅ ổn định — 3 node Ready, kubeadm, Flannel CNI, ingress-nginx, cert-manager đều chạy tốt, không cần đụng lại phần này.

**Namespace `findsource` (production):** ⚠️ **TRỐNG** — `api` (NestJS) và `mysql` đã bị **xoá hẳn** (kể cả PVC/data) ngày 2026-08-01 để dành cluster học Kubernetes. Có backup SQL tại [`backups/findsource-backup-20260801.sql`](./backups/findsource-backup-20260801.sql). Ingress `findsource` vẫn còn nhưng chỉ còn rule cho `emiu.site` / `www.emiu.site` / `admin.emiu.site` (không có `be.emiu.site`, và `web`/`admin` service cũng chưa từng deploy — 3 domain này sẽ trả 503 nếu gọi).

**Namespace `learn-k8s` (lab học):** ✅ đang chạy — app `learn-api` (Express.js, không DB), 3 replicas, xem [learn-lab/README.md](./learn-lab/README.md). **Domain `be.emiu.site` hiện đang trỏ vào namespace này**, không phải production.

**Certificate SSL:** `findsource-tls` (namespace `findsource`) Ready, đã copy sang `learn-tls` (namespace `learn-k8s`) để lab dùng chung — cả 2 còn hạn dùng, không cần xin lại khi chuyển domain qua lại.

---

## Muốn làm gì tiếp theo?

### A. Tiếp tục học Kubernetes
→ Đọc [learn-lab/README.md](./learn-lab/README.md) và [learn-lab/concepts/](./learn-lab/concepts/). Không cần làm gì thêm ở đây.

### B. Deploy lại production thật (api + mysql)
→ Làm theo phần **"Khôi phục production sau khi dùng chung cluster với lab học"** ở cuối [GETTING-STARTED.md](./GETTING-STARTED.md) — gồm: lấy lại domain từ lab, deploy lại api/mysql, restore data từ backup.

---

## Checklist hạ tầng gốc (không đổi, đã xong từ lâu)

| Bước | Việc | Trạng thái | Ghi chú |
|------|------|------------|---------|
| 1–3 | Hostname, repo, kubeadm prereq | ✅ | Ubuntu 26.04 |
| 4 | Init cp-1 (`172.31.30.134`) | ✅ | |
| 5 | Flannel CNI | ✅ | |
| 6 | Join worker-1, worker-2 | ✅ | 3 node Ready |
| 7 | SSH cp-1, kubectl trên cp-1 | ✅ | Không dùng kubectl laptop |
| 8 | DNS emiu.site/www/be/admin → **13.238.15.194** | ✅ | Public IP worker-1 |
| 8b | SG worker-1: TCP 80, 443 | ✅ | AWS Console |
| 9a | Ingress (hostNetwork + worker-1) | ✅ | |
| 9b | cert-manager | ✅ | |
| 9c | ClusterIssuer letsencrypt-prod | ✅ | |

## Checklist tầng ứng dụng (thay đổi tuỳ mục tiêu A/B ở trên)

| Việc | Trạng thái | Ghi chú |
|------|------------|---------|
| `api` (NestJS) + `mysql` deploy | ❌ đã xoá | Backup có sẵn, xem mục B ở trên để khôi phục |
| `web`, `admin` deploy | ⬜ chưa từng làm | Không cấp thiết — chỉ cần `be.emiu.site` theo yêu cầu hiện tại |
| `learn-api` (lab học) | ✅ chạy | Namespace `learn-k8s`, đang giữ domain `be.emiu.site` |
| CI/CD GitHub Actions | ⬜ chưa làm | Làm sau khi production ổn định lại |

---

## Cluster (snapshot)

```
cp-1       Ready   172.31.30.134   public 52.64.229.174   (control-plane, không chạy app)
worker-1   Ready   172.31.23.25    public 13.238.15.194   ← DNS + Ingress
worker-2   Ready   172.31.26.60    public 13.54.216.178
```

---

## Lệnh kiểm tra nhanh (cp-1)

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide                         # toàn cảnh mọi namespace
kubectl get ingress -A                               # xem domain nào trỏ vào đâu
kubectl get pods,svc,ingress -n findsource
kubectl get pods,svc,ingress -n learn-k8s
kubectl get certificate -A
```

---

## Lỗi đã gặp (xem chi tiết trong errors/)

| Lỗi | File |
|-----|------|
| join timeout SG | [03-join-timeout-aws-security-group.md](./errors/03-join-timeout-aws-security-group.md) |
| laptop kubectl timeout | [04-kubectl-timeout-laptop-private-ip.md](./errors/04-kubectl-timeout-laptop-private-ip.md) |
| Helm ingress timeout | [05-helm-ingress-timeout.md](./errors/05-helm-ingress-timeout.md) |
| cert-manager startupapicheck | [06-cert-manager-startupapicheck.md](./errors/06-cert-manager-startupapicheck.md) |
| PVC Pending, no storage class | [07-pvc-no-storageclass.md](./errors/07-pvc-no-storageclass.md) |
| Pod ImagePullBackOff sau khi chạy lâu ngày (GHCR token revoked) | [08-ghcr-token-revoked.md](./errors/08-ghcr-token-revoked.md) |
| DNS đúng ngoài nhưng SERVFAIL trong cluster (CoreDNS cache) | [09-coredns-negative-cache-acme.md](./errors/09-coredns-negative-cache-acme.md) |
| Certificate không issue dù DNS đã đúng (ACME order expired) | [10-acme-order-expired.md](./errors/10-acme-order-expired.md) |

4 lỗi cuối (07-10) từng xảy ra thật trên chính cluster này ngày 2026-08-01, không phải lý thuyết.

---

## Cách cập nhật file này

Sau khi thay đổi trạng thái thật của cluster (deploy/xoá gì đó), sửa lại phần **"Trạng thái thật hiện tại"** ở đầu file — đừng chỉ tick checklist, vì checklist không phản ánh việc tài nguyên có bị xoá lại sau đó hay không.

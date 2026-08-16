# Tiến độ deploy emiu.site

**Cập nhật lần cuối:** 2026-08-16
**Làm việc trên:** cp-1 — IP hiện tại: `cd aws/terraform && terraform output elastic_ips` (KHÔNG dùng IP cũ trong lịch sử chat/tài liệu trước ngày 2026-08-16)
**Doc chính:** [GETTING-STARTED.md](./GETTING-STARTED.md)

> Khi quay lại sau vài ngày: mở file này trước, đừng tin vào ký ức hay IP đã dùng trước đây — EC2 từng bị relaunch 1 lần khiến toàn bộ IP đổi và cluster cũ mất sạch.

---

## Trạng thái thật hiện tại

**Hạ tầng:** 4 EC2 instance (1 control-plane + 3 worker) — **mới hoàn toàn từ 2026-08-16**, cluster/dữ liệu trước đó (kể cả lab học `learn-k8s`, backend `findsource` cũ) **không còn tồn tại**. Instance ID/Elastic IP quản lý qua Terraform tại [`aws/terraform/`](../aws/terraform/).

**Kubernetes:** ✅ Cluster đã lên — 4 node Ready, ingress-nginx + cert-manager + ClusterIssuer đã cài xong (Bước 1-9 trong [GETTING-STARTED.md](./GETTING-STARTED.md) hoàn tất).

**⚠️ Quyết định thay đổi scope (2026-08-16):** **KHÔNG deploy backend NestJS (`api`) + MySQL nữa** (bỏ hẳn Bước 10/11 của GETTING-STARTED.md, không phải tạm hoãn). Domain `be.emiu.site` dùng cho **`learn-api`** (Express, lab học Kubernetes) — xem [learn-lab/README.md](./learn-lab/README.md). Không còn xung đột domain vì backend thật không deploy.

**Dữ liệu cũ:** backup MySQL cũ tại [`backups/findsource-backup-20260801.sql`](./backups/findsource-backup-20260801.sql) — không cần dùng tới trừ khi sau này đổi ý deploy lại backend thật.

---

## Việc cần làm

| Bước | Việc | Trạng thái |
|------|------|------------|
| 1 | Hostname + `/etc/hosts` trên cả 4 máy | ✅ |
| 2–3 | Copy repo + cài kubeadm/containerd (cả 4 máy) | ✅ |
| 4 | Init control-plane (chỉ cp-1) | ✅ |
| 5 | Flannel CNI | ✅ |
| 6 | Join worker-1, worker-2, worker-3 | ✅ |
| 7 | Xác nhận 4 node Ready | ✅ |
| 8 | DNS emiu.site/www/be/admin → public IP worker-1 mới | ✅ |
| 9 | Ingress + cert-manager + SSL | ✅ |
| ~~10~~ | ~~Secret + deploy `api`/`mysql`~~ | ❌ bỏ, không deploy backend thật nữa |
| ~~11~~ | ~~Build/push image GHCR lần đầu~~ | ❌ bỏ (chỉ áp dụng cho backend thật) |
| — | Deploy `learn-api` lên `be.emiu.site` (namespace `learn-k8s`, 3 pod trải đều 3 worker) | ⬜ đang làm — xem [learn-lab/README.md](./learn-lab/README.md) |

---

## Cluster (điền lại sau khi có IP thật — đừng chép từ tài liệu cũ)

```
cp-1       ?   private ?   public ?
worker-1   ?   private ?   public ?   ← DNS + Ingress
worker-2   ?   private ?   public ?
worker-3   ?   private ?   public ?
```

Lấy nhanh:
```bash
cd aws/terraform && terraform output elastic_ips
```

---

## Lệnh kiểm tra nhanh (cp-1, sau khi cluster đã lên)

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get ingress -A
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

Tất cả từng xảy ra thật trên hạ tầng trước đây — nhiều khả năng gặp lại, đọc trước khi debug từ đầu.

---

## Cách cập nhật file này

Sau mỗi bước xong, tick `⬜` → `✅` ở bảng trên, và điền lại bảng "Cluster" với IP thật. Nếu hạ tầng bị thay đổi (relaunch, đổi IP) như đã từng xảy ra — cập nhật lại phần "Trạng thái thật hiện tại" ngay, đừng để tài liệu chỉ toàn IP chết.

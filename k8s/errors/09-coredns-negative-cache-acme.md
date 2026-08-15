# CoreDNS cache lỗi cũ — thêm DNS record rồi vẫn SERVFAIL trong cluster

## Triệu chứng

Đã thêm DNS record đúng, `dig` từ laptop/ngoài internet ra kết quả đúng — nhưng `Certificate` vẫn `READY: False` mãi, và:

```bash
kubectl describe challenge <tên-challenge> -n findsource
```

```text
Waiting for HTTP-01 challenge propagation: failed to perform self check GET request
'http://be.emiu.site/.well-known/acme-challenge/...':
dial tcp: lookup be.emiu.site on 10.96.0.10:53: server misbehaving
```

## Nguyên nhân

**DNS đúng ở ngoài internet ≠ DNS đúng bên trong cluster.** Cluster dùng **CoreDNS** riêng (namespace `kube-system`) để resolve tên miền — CoreDNS có cache. Nếu domain **chưa tồn tại lúc cert-manager thử lần đầu** (ví dụ bạn quên thêm record `be`, thêm bù sau), CoreDNS **cache lại kết quả lỗi (SERVFAIL)** trong 1 khoảng thời gian — dù DNS provider đã trả đúng, CoreDNS vẫn trả kết quả cache cũ cho tới khi cache hết hạn hoặc bị xoá.

## Cách xác nhận đúng là do cache

So sánh DNS ở 2 nơi:

```bash
# Từ laptop — DNS thật (thường đã đúng)
dig +short be.emiu.site A

# Từ TRONG cluster — DNS mà app thấy
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup be.emiu.site
```

Nếu laptop ra kết quả đúng nhưng trong cluster `SERVFAIL`/`NXDOMAIN` → đúng là CoreDNS cache lỗi cũ.

## Fix

```bash
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=60s
```

Đợi ~10-15s rồi test lại `nslookup` trong cluster — phải ra đúng IP. Sau đó cert-manager sẽ tự retry challenge (không cần làm gì thêm) — nhưng nếu challenge đã ở trạng thái `expired`, phải xem thêm [10-acme-order-expired.md](./10-acme-order-expired.md).

## Cách tránh lần sau

Thêm **tất cả DNS record cần thiết cùng lúc, trước khi apply Ingress/Certificate** — không thêm bù thiếu sau. Xem Bước 8 trong [GETTING-STARTED.md](../GETTING-STARTED.md).

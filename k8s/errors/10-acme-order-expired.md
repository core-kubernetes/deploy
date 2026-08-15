# ACME order/challenge expired — Certificate không tự issue được nữa dù DNS đã đúng

## Triệu chứng

Đã fix xong DNS (kể cả cache CoreDNS — xem [09-coredns-negative-cache-acme.md](./09-coredns-negative-cache-acme.md)), nhưng `Certificate` vẫn `READY: False`, và:

```bash
kubectl get challenge -n findsource
```

```text
NAME                                     STATE     DOMAIN
findsource-tls-1-...-2105016830          expired   be.emiu.site
```

## Nguyên nhân

Nếu 1 challenge bị `pending` **quá lâu** (domain lỗi DNS kéo dài nhiều giờ/nhiều ngày), **ACME authorization phía Let's Encrypt tự hết hạn**. Order cũ (`kubectl get order -n findsource`) trở thành rác — **không có cơ chế tự retry lại từ order đã expired**, dù nguyên nhân gốc (DNS) đã fix xong.

## Fix — xoá sạch để tạo order mới hoàn toàn

```bash
kubectl delete challenge -n findsource --all
kubectl delete certificaterequest -n findsource --all
kubectl delete certificate findsource-tls -n findsource
```

`cert-manager-ingress-shim` sẽ tự phát hiện Ingress vẫn cần cert (annotation `cert-manager.io/cluster-issuer`) và **tự tạo lại Certificate mới** trong vài giây — không cần `kubectl apply` lại gì thêm. Domain nào đã từng valid gần đây (Let's Encrypt cache authorization ~30 ngày) thường **pass ngay không cần challenge lại**; chỉ domain lỗi mới cần challenge mới.

Kiểm tra:

```bash
kubectl get certificate,certificaterequest,order,challenge -n findsource
```

Đợi tới khi:

```bash
kubectl get certificate findsource-tls -n findsource
# READY = True
```

Nếu muốn theo dõi tự động thay vì tự gõ lại lệnh liên tục:

```bash
until kubectl get certificate findsource-tls -n findsource \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q True; do
  sleep 10
done
echo "CERT READY"
```

## Cách tránh lần sau

Fix DNS/nguyên nhân gốc **càng sớm càng tốt** sau khi thấy `Certificate READY: False` — đừng để pending kéo dài nhiều giờ/ngày. Theo dõi sớm bằng:

```bash
kubectl get certificate -n findsource -w
```

# GHCR token bị revoke — pod chạy lâu ngày bỗng ImagePullBackOff

## Triệu chứng

Pod đã **Running ổn định nhiều ngày/tuần** bỗng chuyển `ImagePullBackOff` / `ErrImagePull` — thường ngay sau khi node reboot hoặc pod bị xoá/tạo lại.

```text
Failed to pull image "ghcr.io/phamtuankhoi/findsource-api:production":
failed to resolve image: failed to authorize: failed to fetch oauth token:
... 403 Forbidden
```

## Nguyên nhân

Pod cũ chạy được vì **image đã cache sẵn trên node** — không cần pull lại nên không cần token. Khi node reboot hoặc pod bị kill, kubelet phải **pull lại từ đầu** → lúc này token trong `ghcr-secret` mới thật sự bị GitHub kiểm tra.

**Token có thể bị vô hiệu hoá TRƯỚC ngày hết hạn ghi trên GitHub** — do:

- Bị GitHub secret-scanning tự động thu hồi (token lộ ra ở đâu đó public)
- Bị thu hồi thủ công (bạn hoặc người khác xoá trong Settings)

"Còn hạn" (chưa tới ngày expire) **không đồng nghĩa với "còn hoạt động"**.

## Cách chẩn đoán nhanh

```bash
cd deploy/k8s && set -a && source .env.ghcr && set +a
curl -s -o /dev/null -w "%{http_code}\n" -u "$GITHUB_USER:$GITHUB_PAT" https://api.github.com/user
```

- `200` → token còn dùng được, lỗi nằm ở chỗ khác (kiểm tra `kubectl get secret ghcr-secret -n findsource` đã đúng namespace chưa)
- `401` → token đã bị revoke, phải tạo token mới

## Fix

1. Tạo PAT mới: github.com/settings/tokens (classic) → scope `read:packages` (thêm `write:packages` nếu cũng push từ máy này)
2. Cập nhật `deploy/k8s/.env.ghcr` (`GITHUB_PAT=...`)
3. Tạo lại secret trên cluster:
   ```bash
   # scp .env.ghcr lên cp-1 trước nếu sửa trên laptop
   NAMESPACE=findsource bash scripts/05b-create-ghcr-secret.sh
   ```
4. Xoá pod cũ để nó pull lại bằng secret mới:
   ```bash
   kubectl delete pod -n findsource -l app=api
   ```

## Cách tránh lần sau

- Đặt lịch kiểm tra token định kỳ (script chẩn đoán ở trên) thay vì chỉ tin vào ngày hết hạn
- Dùng PAT **fine-grained** với scope tối thiểu, thời hạn rõ ràng, dễ theo dõi hơn PAT classic

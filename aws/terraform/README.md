# Elastic IP cho 4 server (cp-1, worker-1, worker-2, worker-3)

Mục đích: gắn IP tĩnh (Elastic IP) vào 4 instance hiện có, để khi **stop/start** lại server, public IP **không đổi** — không cần sửa lại SSH config / DNS / kubeconfig mỗi lần bật máy.

Instance ID đang quản lý (region `ap-southeast-2`):

| Name         | Instance ID         |
| ------------ | ------------------- |
| control-plan | i-04318a85a8b22639c |
| worker-1     | i-0fb49c4b52fe4496b |
| worker-2     | i-0649ef8f0f74e5e3a |
| worker-3     | i-09dd3ba005a114b7a |

> Sửa ở [variables.tf](./variables.tf) nếu ID thay đổi.

## 1. Kiểm tra credentials đã đúng chưa

```bash
aws sts get-caller-identity
```

Phải trả về `Account` / `UserId` / `Arn`, không lỗi `InvalidClientTokenId`.

## 2. Init + xem trước thay đổi

```bash
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws/terraform"
terraform init
terraform plan
```

Kỳ vọng: `Plan: 4 to add, 0 to change, 0 to destroy` — tạo 4 `aws_eip` và gắn vào 4 instance ở trên.

## 3. Apply (tạo + gắn IP — IP đổi ngay lúc này)

```bash
terraform apply
```

Gõ `yes` khi được hỏi xác nhận.

⚠️ **Lưu ý khi apply:**

- Public IP của cả 4 server đổi **ngay lập tức**, không cần đợi stop/start.
- SSH session đang mở tới IP cũ sẽ bị rớt kết nối.
- `be.emiu.site` (đang trỏ DNS tới IP cũ của worker chạy ingress-nginx) sẽ lỗi 503/timeout cho tới khi cập nhật DNS ở bước 5.

## 4. Lấy IP mới

```bash
terraform output elastic_ips
```

Kết quả mẫu:

```
elastic_ips = {
  "control-plan" = "3.xx.xx.xx"
  "worker-1"     = "3.xx.xx.xx"
  "worker-2"     = "3.xx.xx.xx"
  "worker-3"     = "3.xx.xx.xx"
}
```

## 5. Cập nhật sau khi apply

- [ ] Sửa `~/.ssh/config` (nếu có) và [../ec2.md](../ec2.md) với IP mới cho từng server (file hiện đang cũ, IP không còn đúng).
- [ ] Sửa DNS record `be.emiu.site` → trỏ sang Elastic IP mới của node đang chạy ingress-nginx (theo [TEST.md](../../k8s/learn-lab/TEST.md) hiện là worker-1, xác nhận lại bằng `kubectl get nodes -o wide` trước khi sửa).
- [ ] Test SSH lại từng server bằng IP mới:
- [ ] Test cluster + domain sau khi DNS propagate:

## 6. Từ giờ về sau

Elastic IP đã gắn cố định vào từng instance — **tắt/mở lại server bao nhiêu lần cũng giữ nguyên IP này**, không cần chạy lại Terraform. Chỉ chạy lại `terraform apply` nếu bạn thêm/xóa server.

Không chạy `terraform destroy` trừ khi thực sự muốn nhả 4 IP này về lại AWS (sau đó IP sẽ đổi ngẫu nhiên mỗi lần stop/start như cũ).

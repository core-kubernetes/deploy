# Giải thích các file Terraform (cho người mới)

Thư mục [aws/terraform/](.) có 5 file, mỗi file một vai trò riêng. Terraform tự động đọc **tất cả** file `.tf` trong thư mục cùng lúc (không quan trọng tên file), việc chia nhỏ 3 file `main.tf` / `variables.tf` / `outputs.tf` chỉ là quy ước cho dễ đọc — gộp chung vào 1 file cũng chạy y hệt.

## Khái niệm cần biết trước

| Từ                              | Nghĩa                                                                                                                                         |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Provider**                    | "Nhà cung cấp" hạ tầng — ở đây là AWS. Terraform cần biết dùng provider nào để gọi API của AWS.                                               |
| **Resource**                    | Một "thứ" thật sẽ được tạo trên AWS (server, Elastic IP, security group...). Mỗi resource trong file `.tf` = 1 object thật trên AWS.          |
| **Variable**                    | Biến — giá trị có thể thay đổi mà không phải sửa logic chính (vd instance ID, region).                                                        |
| **Output**                      | Giá trị Terraform in ra màn hình sau khi `apply` xong, để bạn xem kết quả (vd IP mới được cấp).                                               |
| **State** (`terraform.tfstate`) | File Terraform tự tạo, ghi nhớ "mình đã tạo cái gì rồi". Nhờ file này mà lần sau chạy `apply`, Terraform biết cái gì đã có → không tạo trùng. |
| **plan**                        | Chạy thử, xem trước sẽ thay đổi gì — **chưa đụng gì tới AWS thật**.                                                                           |
| **apply**                       | Thực thi thật — tạo/sửa/xoá tài nguyên trên AWS.                                                                                              |

## 1. [main.tf](./main.tf) — nội dung chính

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
```

→ "Tôi cần dùng provider AWS, bản 5.x". Terraform sẽ tự tải plugin này về khi chạy `terraform init`.

```hcl
provider "aws" {
  region = var.aws_region
}
```

→ Cấu hình provider AWS dùng region nào (lấy từ file `variables.tf`, hiện là `ap-southeast-2`). Terraform tự lấy access key/secret từ `~/.aws/credentials` trên máy bạn, không cần ghi trong file này.

```hcl
resource "aws_eip" "this" {
  for_each = var.instance_ids
  instance = each.value
  domain   = "vpc"
  tags = { Name = "${each.key}-eip" }
}
```

→ Đây là phần **tạo Elastic IP thật**. Đọc như sau:

- `resource "aws_eip" "this"`: tạo 1 resource loại `aws_eip` (Elastic IP), đặt tên nội bộ trong Terraform là `this`.
- `for_each = var.instance_ids`: thay vì viết tay 4 lần, lặp qua map 4 instance trong `variables.tf` → tự tạo 4 Elastic IP, mỗi cái ứng với 1 server.
- `instance = each.value`: gắn EIP vừa tạo vào đúng instance ID đó.
- `domain = "vpc"`: bắt buộc phải có, nghĩa là IP dùng cho VPC (mọi server AWS hiện đại đều nằm trong VPC).
- `tags`: gắn nhãn tên trên AWS Console cho dễ nhận diện (vd `worker-1-eip`), không ảnh hưởng chức năng.

## 2. [variables.tf](./variables.tf) — nơi khai báo biến

```hcl
variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "instance_ids" {
  type = map(string)
  default = {
    control-plan = "i-04318a85a8b22639c"
    worker-1     = "i-0fb49c4b52fe4496b"
    worker-2     = "i-0649ef8f0f74e5e3a"
    worker-3     = "i-09dd3ba005a114b7a"
  }
}
```

→ Tách riêng "dữ liệu hay đổi" (region, danh sách instance ID) ra khỏi "logic" (`main.tf`). Sau này thêm/bớt server, hoặc đổi ID, chỉ cần sửa file này, không đụng vào `main.tf`.

`map(string)` = một danh sách kiểu `tên → giá trị`, giống object trong JSON:

```json
{ "worker-1": "i-0fb49c4b52fe4496b", ... }
```

## 3. [outputs.tf](./outputs.tf) — in kết quả ra màn hình

```hcl
output "elastic_ips" {
  value = { for name, eip in aws_eip.this : name => eip.public_ip }
}
```

→ Sau khi `apply` xong, Terraform biết IP thật mà AWS vừa cấp (lúc viết file này thì **chưa biết**, AWS cấp ngẫu nhiên lúc tạo). Output này lấy IP đó ra và in đẹp theo dạng `tên server → IP`, để bạn không phải tự vào AWS Console tìm từng cái. Xem bằng lệnh:

```bash
terraform output elastic_ips
```

## 4. [.gitignore](./.gitignore) — không commit file nhạy cảm/rác

```
.terraform/
terraform.tfstate
terraform.tfstate.*
*.tfvars
```

→ Ngăn Git commit nhầm:

- `.terraform/`: thư mục Terraform tự tải plugin AWS về (nặng, máy ai chạy tự tải lại được, không cần lưu).
- `terraform.tfstate`: file "bộ nhớ" của Terraform — **có thể chứa thông tin nhạy cảm** (như chi tiết resource), không nên đưa lên Git.
- `*.tfvars`: nếu sau này bạn tạo file chứa giá trị bí mật (vd access key) thì cũng bị chặn không cho commit.

## 5. [README.md](./README.md) — hướng dẫn chạy lệnh

Không phải code, chỉ là tài liệu các bước: kiểm tra credentials → `init` → `plan` (xem trước) → `apply` (chạy thật) → lấy IP mới → checklist việc cần làm sau đó (sửa DNS, sửa `ec2.md`...). Đọc file này khi bạn thực sự bấm lệnh.

## Tóm tắt luồng chạy

```
terraform init    → tải "driver" nói chuyện với AWS về
terraform plan    → xem trước: sẽ tạo 4 Elastic IP, gắn vào 4 server nào
terraform apply   → tạo thật trên AWS, IP đổi ngay lúc này
terraform output  → in ra 4 IP mới vừa được cấp
```

Từ sau khi `apply` thành công, 4 IP này **cố định vĩnh viễn** cho tới khi bạn chủ động `terraform destroy` (nhả IP) — tắt/mở lại server bao nhiêu lần cũng không đổi IP nữa.

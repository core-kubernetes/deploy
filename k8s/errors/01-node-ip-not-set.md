# Lỗi: NODE_IP chưa set khi chạy `03-init-control-plane.sh`

## Triệu chứng

```text
sudo -E bash 03-init-control-plane.sh
sudo: preserving the entire environment is not supported, '-E' is ignored
03-init-control-plane.sh: line 5: NODE_IP: Set NODE_IP — IP mà API Server advertise...
```

## Nguyên nhân

- Script cần biết **IP mà API Server lắng nghe** (`--apiserver-advertise-address`).
- Biến `NODE_IP` chưa export, và `sudo -E` trên một số máy **không** truyền env sang root.

## Cách fix

**Cách 1 — truyền IP làm tham số (khuyến nghị trên AWS):**

```bash
# Private IP cp-1 (worker cùng VPC join qua IP này)
sudo bash 03-init-control-plane.sh 172.31.30.134
```

**Cách 2 — script tự lấy IP đầu tiên:**

```bash
sudo bash 03-init-control-plane.sh
```

**Chọn IP nào?**

| Môi trường | Dùng |
|------------|------|
| AWS, worker cùng VPC | **Private IP** cp-1 (vd. `172.31.30.134`) |
| Worker chỉ reach qua internet | Public IP cp-1 (hiếm) |

Xem IP:

```bash
hostname -I
ip -4 addr show
```

## Cách tránh

- Script `03-init-control-plane.sh` đã hỗ trợ tham số IP — không cần `export NODE_IP` + `sudo -E`.
- Luôn dùng **cùng IP** khi worker `kubeadm join` (trong lệnh join in ra từ init).

## Liên quan

- [../GETTING-STARTED.md](../GETTING-STARTED.md) — Bước 4

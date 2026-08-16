1. truy cập -i

cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i cp.pem [ubuntu@13.236.58.150](mailto:ubuntu@13.236.58.150) # control-plane (cp-1)
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-1.pem [ubuntu@54.66.76.232](mailto:ubuntu@54.66.76.232) # worker-1
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-2.pem [ubuntu@54.66.124.201](mailto:ubuntu@54.66.124.201) # worker-2
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-2.pem [ubuntu@13.211.26.22](mailto:ubuntu@13.211.26.22) # worker-3 — dùng CHUNG key pair với worker-2 (AWS key name "worker-2")

chmod 400 cp.pem worker-1.pem worker-2.pem

1. Tốt nhất: SSH Config + Terminal

Copy key:

mkdir -p ~/.ssh
cp cp.pem worker-1.pem worker-2.pem ~/.ssh/
chmod 400 ~/.ssh/cp.pem ~/.ssh/worker-1.pem ~/.ssh/worker-2.pem

Tạo:

nano ~/.ssh/config

Thêm (IP lấy từ `terraform output elastic_ips` — có thể khác ví dụ dưới):

Host aws-cp
HostName 13.xxx.xxx.xxx
User ubuntu
IdentityFile ~/.ssh/cp.pem

Host aws-worker-1
HostName 54.xxx.xxx.xxx
User ubuntu
IdentityFile ~/.ssh/worker-1.pem

Host aws-worker-2
HostName 54.xxx.xxx.xxx
User ubuntu
IdentityFile ~/.ssh/worker-2.pem

Host aws-worker-3
HostName 13.xxx.xxx.xxx
User ubuntu
IdentityFile ~/.ssh/worker-2.pem

Sau đó:

ssh aws-cp # hoặc aws-worker-1 / aws-worker-2 / aws-worker-3

Ưu điểm:

Nhanh
Không cần nhớ IP
Không cần nhớ đường dẫn key
VS Code Remote SSH dùng được luôn
Quản lý 10-20 server vẫn ổn

---

## 3. Security Group — kubeadm join (bắt buộc)

Lỗi `context deadline exceeded` khi `kubeadm join` từ worker → **worker không tới được cp-1:6443**.

⚠️ **Lưu ý:** 4 instance (cp-1, worker-1, worker-2, worker-3) mỗi cái có **Security Group RIÊNG** (không dùng chung 1 SG) — phải mở port trên **cả 4 SG**, không phải chỉ SG của cp-1.

**Cách nhanh nhất — script tự động** (chạy từ laptop, không cần vào AWS Console):

```bash
bash aws/scripts/open-k8s-security-groups.sh
```

Script tự tra SG ID của cả 4 instance theo tag Name và mở đủ port bên dưới, chạy lại nhiều lần không lỗi.

**Cách tay (nếu không dùng script được)** — vào **AWS Console → EC2 → Security Groups**, mở trên **từng SG của cả 4 instance**:

| Type       | Port        | Source                       | Mục đích             |
| ---------- | ----------- | ---------------------------- | -------------------- |
| Custom TCP | **6443**    | **172.31.0.0/16** (VPC CIDR) | API Server           |
| Custom TCP | 10250       | 172.31.0.0/16                | kubelet              |
| Custom TCP | 2379-2380   | 172.31.0.0/16                | etcd (cp-1)          |
| Custom TCP | 10257-10259 | 172.31.0.0/16                | control plane (cp-1) |
| UDP        | **8472**    | 172.31.0.0/16                | Flannel VXLAN        |
| Custom TCP | 30000-32767 | 0.0.0.0/0 (tuỳ chọn)         | NodePort / Ingress   |

Kiểm tra từ **mỗi worker** (thay IP private cp-1 hiện tại — xem `kubectl get nodes -o wide` hoặc `hostname -I` trên cp-1):

```bash
nc -zv <IP-private-cp-1> 6443
# Connection succeeded → join lại
```

Sau khi sửa SG, trên từng worker:

```bash
sudo kubeadm join <IP-private-cp-1>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Chi tiết: [../k8s/errors/03-join-timeout-aws-security-group.md](../k8s/errors/03-join-timeout-aws-security-group.md)

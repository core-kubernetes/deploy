1. truy cập -i

cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i control-plan-1.pem ubuntu@13.236.58.150
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-1.pem ubuntu@54.66.76.232
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-2.pem ubuntu@54.66.124.201
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-2.pem ubuntu@13.211.26.22

chmod 400 control-plan-1.pem

2. Tốt nhất: SSH Config + Terminal

Copy key:

mkdir -p ~/.ssh
cp control-plan-1.pem ~/.ssh/
chmod 400 ~/.ssh/control-plan-1.pem

Tạo:

nano ~/.ssh/config

Thêm:

Host aws-master
HostName 54.xxx.xxx.xxx
User ubuntu
IdentityFile ~/.ssh/control-plan-1.pem

Sau đó:

ssh aws-master

Ưu điểm:

Nhanh
Không cần nhớ IP
Không cần nhớ đường dẫn key
VS Code Remote SSH dùng được luôn
Quản lý 10-20 server vẫn ổn

---

## 3. Security Group — kubeadm join (bắt buộc)

Lỗi `context deadline exceeded` khi `kubeadm join` từ worker → **worker không tới được cp-1:6443**.

Trong **AWS Console → EC2 → Security Groups**, gắn rule cho **SG của cp-1** (và nên giống nhau cho cả 3 instance):

| Type       | Port        | Source                                          | Mục đích             |
| ---------- | ----------- | ----------------------------------------------- | -------------------- |
| Custom TCP | **6443**    | **172.31.0.0/16** (VPC CIDR) hoặc SG của worker | API Server           |
| Custom TCP | 10250       | 172.31.0.0/16                                   | kubelet              |
| Custom TCP | 2379-2380   | 172.31.0.0/16                                   | etcd (cp-1)          |
| Custom TCP | 10257-10259 | 172.31.0.0/16                                   | control plane (cp-1) |
| UDP        | **8472**    | 172.31.0.0/16                                   | Flannel VXLAN        |
| Custom TCP | 30000-32767 | 0.0.0.0/0 (tuỳ chọn)                            | NodePort / Ingress   |

**Cách nhanh (lab):** Inbound trên SG cp-1 + worker: **All traffic**, Source = **SG id của chính nó** (3 instance cùng 1 SG).

Kiểm tra từ **worker-1**:

```bash
nc -zv 172.31.30.134 6443
# Connection succeeded → join lại
```

Sau khi sửa SG, trên worker-1:

```bash
sudo kubeadm join 172.31.30.134:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Chi tiết: [../k8s/errors/03-join-timeout-aws-security-group.md](../k8s/errors/03-join-timeout-aws-security-group.md)

# Lỗi: `kubeadm join` — `context deadline exceeded` (AWS Security Group)

## Triệu chứng

Trên **worker-1** (hoặc worker-2):

```text
sudo kubeadm join 172.31.30.134:6443 --token ... --discovery-token-ca-cert-hash sha256:...
[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server:
failed to request the cluster-info ConfigMap:
Get "https://172.31.30.134:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s":
context deadline exceeded
```

Test mạng:

```bash
# worker-1
nc -zv 172.31.30.134 6443
# nc: connect to 172.31.30.134 port 6443 (tcp) failed: Connection timed out
```

Trong khi trên **cp-1** API vẫn OK:

```bash
sudo ss -tlnp | grep 6443          # kube-apiserver LISTEN *:6443
curl -k https://172.31.30.134:6443/healthz   # ok
```

## Nguyên nhân

- **Không phải lỗi token** — worker không **kết nối TCP** tới cp-1 port **6443**.
- Trên **AWS EC2**, mỗi instance thường có **Security Group riêng**:
  - `control-plan-1` → `launch-wizard-1`
  - `worker-1` → `launch-wizard-2`
  - `worker-2` → `launch-wizard-3`
- SG mặc định của cp-1 thường **chỉ mở SSH 22**, **chặn 6443** từ worker.

## Cách fix

### Bước 1 — Xác nhận

Trên worker, sau khi sửa SG phải thấy:

```bash
nc -zv 172.31.30.134 6443
# Connection to 172.31.30.134 6443 port [tcp/*] succeeded!
```

### Bước 2 — Mở port trên SG của **cp-1** (`launch-wizard-1`)

**EC2 → Security Groups → launch-wizard-1 → Inbound rules → Edit**

**Cách A — đơn giản (cả VPC):**

| Type | Port | Source |
|------|------|--------|
| Custom TCP | 6443 | `172.31.0.0/16` |

**Cách B — chặt (đã dùng trong project):** mỗi worker một rule:

| Type | Port | Source | Mô tả |
|------|------|--------|--------|
| Custom TCP | 6443 | SG `launch-wizard-2` | worker-1 |
| Custom TCP | 6443 | SG `launch-wizard-3` | worker-2 |

**Không dùng** `0.0.0.0/0` (Anywhere-IPv4) cho 6443 — lộ API ra internet.

**Save rules.**

### Bước 3 — Join lại

Token hết hạn (~24h)? Trên **cp-1**:

```bash
kubeadm token create --print-join-command
```

Trên worker:

```bash
sudo kubeadm join 172.31.30.134:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Thành công khi thấy: `This node has joined the cluster.`

### Bước 4 — Sau join: Flannel (UDP 8472)

Trên SG **cp-1** (và nên cả worker), thêm Inbound từ worker SG hoặc `172.31.0.0/16`:

| Type | Port | Mục đích |
|------|------|----------|
| UDP | 8472 | Flannel VXLAN — Pod network |

Thiếu rule này: node có thể **Ready** nhưng Pod sau này không ping được nhau.

Tuỳ chọn thêm trên cp-1 Inbound:

| Port | Mục đích |
|------|----------|
| TCP 10250 | kubelet |
| TCP 2379-2380 | etcd |

## Phân biệt nhanh

| cp-1 healthz | worker nc 6443 | Nguyên nhân |
|--------------|----------------|-------------|
| ok | timeout | **Security Group / NACL** |
| fail | timeout | API chưa chạy / sai IP |
| ok | succeeded | Join lại — lỗi token nếu vẫn fail |

## Vẫn timeout sau khi sửa SG?

1. **Network ACL** (VPC → Subnet): allow 6443 + ephemeral ports.
2. cp-1 và worker **cùng VPC**, cùng region.
3. Trên worker: `curl -k --connect-timeout 5 https://172.31.30.134:6443/healthz`

## Cách tránh lần sau

- Dùng **chung 1 Security Group** cho 3 node + rule “All traffic from self”.
- Hoặc document SG rules trước khi init (xem [../../aws/ec2.md](../../aws/ec2.md)).

## Liên quan

- [../GETTING-STARTED.md](../GETTING-STARTED.md) — Bước 6
- [../../aws/ec2.md](../../aws/ec2.md) — mục Security Group

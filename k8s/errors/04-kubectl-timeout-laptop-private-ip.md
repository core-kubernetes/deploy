# Laptop `kubectl` timeout — `172.31.x.x:6443`

Kubeconfig trỏ **IP private** cp-1. Laptop ngoài VPC không kết nối được.

**Cách làm:** SSH vào cp-1, chạy `kubectl` trên đó — xem [../GETTING-STARTED.md](../GETTING-STARTED.md) Bước 7.

**Tuỳ chọn — SSH tunnel từ Mac:**

```bash
# Terminal 1
ssh -i control-plan-1.pem -N -L 6443:172.31.30.134:6443 ubuntu@52.64.229.174

# Terminal 2
kubectl config set-cluster kubernetes --server=https://127.0.0.1:6443
kubectl get nodes
```

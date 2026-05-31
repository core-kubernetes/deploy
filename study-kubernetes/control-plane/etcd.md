# etcd

## Định nghĩa

**etcd** là kho **key-value** nhất quán, highly available, dùng làm **backing store** cho mọi dữ liệu API Server của Kubernetes.

> *"Consistent and highly-available key value store for all API server data."*

---

## Vai trò

| | |
|---|---|
| **Lưu gì** | Toàn bộ object cluster: Pod, Deployment, Secret, ConfigMap, RBAC, Node, v.v. |
| **Không lưu gì** | Nội dung container, log app, file trong volume (trừ khi bạn lưu vào ConfigMap/Secret) |
| **Ai ghi** | Chủ yếu **kube-apiserver** — component khác không ghi trực tiếp etcd thông thường |

```
kubectl apply  →  API Server  →  etcd
kubectl get    →  API Server  ←  etcd
```

---

## Tại sao cần HA?

etcd dùng **Raft consensus**: cần **quorum** (đa số) để commit.

| Số node etcd | Chịu được mất |
|--------------|---------------|
| 1 | 0 (single point of failure) |
| 3 | 1 node |
| 5 | 2 node |

**Quy tắc:** số node etcd **lẻ** (3, 5) — không dùng 2 node (quorum kém hiệu quả).

---

## Backup và phục hồi

| Rủi ro | Hậu quả |
|--------|---------|
| Mất etcd không backup | Mất toàn bộ desired state — Deployment, Secret, Ingress… |
| Container vẫn chạy tạm | Process trên node chưa bị kill ngay, nhưng không scale/sửa được qua API |

```bash
# etcdctl snapshot (cluster self-managed — cần cert etcd)
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/path/ca.crt --cert=/path/etcd.crt --key=/path/etcd.key
```

**kubeadm:** dữ liệu etcd tại `/var/lib/etcd` — backup định kỳ khi production.

**Lưu ý:** backup MySQL app (`07-backup-mysql.sh`) **khác** backup etcd.

---

## Performance

- etcd nhạy **latency disk** — dùng SSD, tránh disk đầy
- Object quá lớn (ConfigMap khổng lồ) làm chậm cluster
- Watch nhiều client → tải trên API/etcd tăng

---

## Bảo mật

- etcd **phải** TLS, không expose public internet
- Chỉ API Server (và etcd peers) kết nối được
- Secret trong etcd **at rest** có thể mã hoá (EncryptionConfiguration KMS)

---

## Liên hệ findsource

Khi bạn apply overlay production, trong etcd xuất hiện (ví dụ):

- Namespace `findsource`
- Deployment `api`, `web`, `admin`
- StatefulSet `mysql`, PVC
- Secret DB credentials
- Ingress `emiu.site`

Mất data etcd **mà không backup** = phải `kubectl apply` lại toàn bộ manifest (Secret cần tạo lại).

---

## Tài liệu tham khảo

- [Operating etcd clusters for Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- [Set up a High Availability etcd Cluster with kubeadm](https://kubernetes.io/docs/setup/learning-environment/#etcd)

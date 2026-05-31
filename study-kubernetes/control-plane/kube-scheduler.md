# kube-scheduler

## Định nghĩa

**kube-scheduler** theo dõi Pod **chưa được gán node** (`spec.nodeName` rỗng) và **chọn một node** phù hợp cho mỗi Pod.

> *"Looks for Pods not yet bound to a node, and assigns each Pod to a suitable node."*

---

## Scheduler **không** làm gì

| Không thuộc scheduler | Ai làm |
|------------------------|--------|
| Tạo Pod | Controller (Deployment → ReplicaSet → Pod) |
| Chạy container | kubelet + container runtime |
| Scale số replica | Deployment controller |
| Routing Service | kube-proxy / CNI |

Scheduler chỉ **gán node** (binding).

---

## Quy trình scheduling (đơn giản)

```
Pod mới (Pending, chưa có nodeName)
        ↓
   Filtering — loại node không đủ điều kiện
        ↓
   Scoring — xếp hạng node còn lại
        ↓
   Binding — ghi nodeName vào Pod (qua API)
        ↓
   kubelet trên node đó nhận Pod → chạy container
```

---

## Tiêu chí filtering / scoring (ví dụ)

| Tiêu chí | Ý nghĩa |
|----------|---------|
| **Resource requests** | CPU/memory requests có fit node không |
| **nodeSelector / affinity** | Pod chỉ chạy node có label |
| **Taints & tolerations** | Pod có toleration mới vào node bị taint |
| **Pod affinity/anti-affinity** | Cùng rack với cache, tránh cùng node với replica khác |
| **Topology spread** | Trải Pod đều zone/rack |
| **Volume topology** | PVC zone phải khớp node (quan trọng với mysql-0) |

**Findsource:** Pod `mysql-0` + PVC local/zone → scheduler chọn node có volume phù hợp.

---

## Trạng thái Pod Pending

```bash
kubectl describe pod <tên> -n findsource
# Events: 0/2 nodes are available: insufficient memory, ...
```

Nguyên nhân thường gặp:

- Không đủ CPU/RAM trên mọi node
- Taint master, Pod không có toleration
- PVC chưa Bound
- Affinity không thỏa

---

## Custom scheduler

Có thể chạy **nhiều scheduler** (tên khác trong `spec.schedulerName`). Mặc định: `default-scheduler`.

---

## HA

Nhiều bản scheduler chạy song song; **leader election** — chỉ leader thực hiện schedule, tránh gán trùng.

---

## Liên hệ findsource

| Workload | Ghi chú scheduling |
|----------|-------------------|
| `api`, `web` (Deployment) | Spread 2 replica lên 2 worker nếu đủ node |
| `mysql-0` (StatefulSet) | Ổn định node + disk |
| Pod hệ thống | Thường toleration lên master (CoreDNS) |

---

## Tài liệu tham khảo

- [Kubernetes Scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

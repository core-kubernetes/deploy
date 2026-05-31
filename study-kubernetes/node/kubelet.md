# kubelet

## Định nghĩa

**kubelet** là agent chạy trên **mỗi node**, đảm bảo các **Pod** (và container trong Pod) được chạy đúng như Kubernetes API mô tả.

> *"Ensures that Pods are running, including their containers."*

---

## Vai trò chính

| Nhiệm vụ | Chi tiết |
|-----------|----------|
| **Pod lifecycle** | Tạo, start, stop, restart container theo spec |
| **Mount volumes** | PVC, ConfigMap, Secret volume |
| **Health probes** | `livenessProbe`, `readinessProbe`, `startupProbe` |
| **Report status** | Ghi `Pod.status` (Running, Ready, restart count…) |
| **Resource metrics** | Cung cấp dữ liệu cho metrics-server (summary API) |
| **Image pull** | Kéo image từ registry (GHCR findsource) |
| **Secrets/ConfigMaps** | Mount hoặc inject env |

---

## kubelet không nhận lệnh trực tiếp từ kubectl

```
kubectl delete pod  →  API Server  →  kubelet thấy Pod bị xóa / cần dừng
kubectl logs        →  API Server  →  kubelet (hoặc runtime) trả log stream
```

kubelet **đăng ký** node và **watch** Pod được gán `spec.nodeName` = node của mình.

---

## Static Pods (ngoài lề)

kubelet cũng có thể chạy **static Pod** từ manifest trên disk (`/etc/kubernetes/manifests`) — không qua Deployment. Control plane components (api-server, etcd) trên kubeadm thường là static Pod.

**kubeadm:** kubelet chạy systemd service trên mỗi node — `systemctl status kubelet`.

---

## Probes — findsource

Trong `deploy/k8s/base/api/deployment.yaml`:

```yaml
readinessProbe:
  httpGet:
    path: /process
    port: 7003
livenessProbe:
  httpGet:
    path: /process
    port: 7003
```

| Probe | kubelet làm gì |
|-------|----------------|
| **Readiness** | Fail → Pod removed khỏi Service endpoints (không nhận traffic) |
| **Liveness** | Fail → restart container |
| **Startup** | Trì hoãn liveness khi app khởi động chậm |

```bash
kubectl describe pod -n findsource <pod> | grep -A5 "Liveness\|Readiness"
```

---

## Cgroups & resources

kubelet enforce `resources.requests/limits`:

- CPU limit → cgroup quota
- Memory limit → OOM kill container nếu vượt

Pod không set requests → Scheduler khó tính toán; có thể bị **BestEffort** QoS.

---

## Node pressure eviction

Khi node thiếu disk/memory, kubelet **evict** Pod theo QoS (BestEffort trước).

```bash
kubectl describe node | grep -i pressure
```

---

## CRI — giao tiếp runtime

kubelet không gọi `docker run` trực tiếp; dùng **CRI** (Container Runtime Interface) tới containerd/CRI-O.

→ [container-runtime.md](./container-runtime.md)

---

## Lệnh debug

```bash
kubectl get pods -n findsource -o wide    # cột NODE
kubectl logs -n findsource deployment/api -f
kubectl exec -it -n findsource deployment/api -- sh

# Trên node (cần SSH)
sudo crictl ps
sudo crictl logs <container-id>
```

---

## Tài liệu tham khảo

- [Kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Node-pressure Eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)

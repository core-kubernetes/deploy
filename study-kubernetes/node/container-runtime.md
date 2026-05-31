# Container Runtime

## Định nghĩa

**Container runtime** là phần mềm **thực sự chạy container** (tạo namespace, cgroup, mount rootfs, start process).

> *"Software responsible for running containers."*

Kubernetes core **không** nhúng Docker Engine; giao tiếp qua **CRI** (Container Runtime Interface).

---

## CRI — lớp trừu tượng

```
kubelet  ──gRPC CRI──►  containerd / CRI-O  ──►  runc  ──►  container
```

| Thành phần | Vai trò |
|------------|---------|
| **kubelet** | Gọi CRI: RunPodSandbox, CreateContainer, StartContainer… |
| **containerd** | Daemon quản lý image, container (phổ biến) |
| **runc** | OCI runtime thực thi container (low-level) |

---

## Runtime phổ biến

| Runtime | Ghi chú |
|---------|---------|
| **containerd** | Mặc định kubeadm |
| **CRI-O** | Red Hat / OpenShift ecosystem |
| **Docker Engine** | Không còn dockershim (K8s ≥ 1.24) — containerd vẫn dùng image Docker format |

Đọc thêm: [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

---

## Image pull — findsource

Deployment api:

```yaml
image: ghcr.io/<org>/findsource-api:production
imagePullSecrets:
  - name: ghcr-cr
```

| Bước | Ai thực hiện |
|------|--------------|
| kubelet thấy Pod cần image mới | |
| Gọi CRI PullImage | containerd |
| Authenticate GHCR | imagePullSecrets |
| Start container | containerd + runc |

```bash
# Trên node
sudo crictl images | grep findsource
sudo crictl ps
```

---

## Pod sandbox

Mỗi Pod có **sandbox** (network namespace chung) — các container trong Pod share IP (localhost giữa container).

Init container, sidecar — cùng sandbox, kubelet quản lý thứ tự start.

---

## RuntimeClass (tuỳ chọn)

Chọn runtime khác cho Pod (ví dụ GPU, kata containers):

```yaml
spec:
  runtimeClassName: nvidia
```

Findsource hiện không dùng RuntimeClass.

---

## cgroup v2

Linux hiện đại dùng **cgroup v2** — kubelet và runtime phải tương thích. Script kubeadm cấu hình `SystemdCgroup = true`.

---

## So sánh với “Docker trên server”

| | `docker run` thủ công | Kubernetes |
|---|----------------------|--------------|
| Ai start container | Bạn | kubelet qua CRI |
| Restart | Docker restart policy | Deployment controller + kubelet |
| Network | bridge docker0 | CNI Pod network |

---

## Tài liệu tham khảo

- [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/)
- [Migrating from dockershim](https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/)

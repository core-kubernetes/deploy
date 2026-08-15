# Bộ máy vận hành ngầm (Control Plane & Node Components)

[01-workload-objects.md](./01-workload-objects.md) giải thích các "đồ vật bạn tạo ra" (Pod, Deployment, Service...). File này giải thích **bộ máy đứng sau**, làm cho các đồ vật đó thật sự hoạt động — đúng theo sơ đồ chính thức trong tài liệu Kubernetes (Control Plane + Node).

## Control Plane (chỉ chạy trên `cp-1`)

### 1. API Server (`kube-apiserver`)

**Cửa duy nhất** để nói chuyện với cluster. Mọi lệnh `kubectl` gửi request tới đây trước — không thành phần nào khác được phép "lách" nói chuyện trực tiếp với etcd hay node.

### 2. etcd

Cuốn **sổ cái** lưu toàn bộ trạng thái cluster: đang có Pod nào, Service nào, Secret gì... dưới dạng key-value. Nếu etcd mất dữ liệu → k8s "quên sạch" nó đang quản lý gì (dù Pod thực tế vẫn chạy) — cực kỳ quan trọng, cần backup định kỳ trong hệ thống thật.

### 3. Controller Manager (`kube-controller-manager`)

Chạy hàng loạt **vòng lặp kiểm tra liên tục**: "thực tế có khớp mong muốn không?" — đây chính là **bộ não đứng sau self-healing**. Khi 1 pod bị xoá, "Deployment Controller" bên trong thành phần này phát hiện thiếu và ra lệnh tạo lại.

### 4. Scheduler (`kube-scheduler`)

Quyết định **pod mới sẽ chạy ở node nào** (dựa vào node nào còn trống tài nguyên, có taint/chặn không...). Là lý do khi tạo 3 pod, Scheduler tự xếp phân bổ vào các worker node — không ngẫu nhiên, có tính toán.

### 5. Cloud Controller Manager (`cloud-controller-manager`) — optional

Cầu nối giữa k8s và API nhà cung cấp cloud (AWS/GCP) — để tự tạo LoadBalancer thật, tự gắn ổ đĩa cloud.

**Cluster này KHÔNG có thành phần này** (kubeadm tự dựng trên EC2 trần, không phải EKS/managed). Đó là lý do phải dùng workaround `hostNetwork: true` + pin Ingress vào `worker-1` thay vì có LoadBalancer tự động như trên EKS/GKE.

## Trên mỗi Node (`worker-1`, `worker-2`, và cả `cp-1`)

### 6. kubelet

**"Quản đốc" đứng ngay tại node** — nhận lệnh từ API Server ("chạy Pod X ở đây"), ra lệnh cho containerd thực sự khởi động container, liên tục báo cáo tình trạng Pod ngược lại.

Không chạy dạng Pod — chạy như 1 **service hệ thống (systemd)** trực tiếp trên node, nên không thấy nó khi chạy `kubectl get pods -n kube-system`.

### 7. kube-proxy

**Thành phần thật sự thực thi load balancing** — Service chỉ là khai báo ý định, `kube-proxy` (chạy trên **mỗi** node, kể cả `cp-1`) mới là kẻ thật sự cấu hình iptables/IPVS để chia traffic đều tới đúng Pod.

## Add-on (không nằm trong sơ đồ chính thức, nhưng cài thêm và rất quan trọng)

### CoreDNS

DNS nội bộ của cluster — dịch tên Service/domain sang IP bên trong cluster. Đây chính là thành phần từng phải **restart** để xoá cache DNS lỗi khi debug SSL cho `be.emiu.site` — chứng minh add-on này ảnh hưởng trực tiếp tới mọi request nội bộ.

## Bằng chứng thật trên cluster

```bash
kubectl get pods -n kube-system -o wide
```

Kết quả quan sát được:

```
etcd-cp-1                      → chỉ cp-1
kube-apiserver-cp-1            → chỉ cp-1
kube-controller-manager-cp-1   → chỉ cp-1
kube-scheduler-cp-1            → chỉ cp-1
kube-proxy-*                   → cả 3 node (cp-1, worker-1, worker-2)
coredns-*                      → worker-1, worker-2
(không có cloud-controller-manager — đúng như giải thích ở trên)
(không thấy kubelet — vì nó không chạy dạng Pod)
```

## 2 tầng tổng hợp

```
Tầng bạn khai báo (workload objects)
   Pod → Deployment → Service → Ingress → Namespace → Secret → PVC/StatefulSet
                              ↑
                    được vận hành bởi
                              ↓
Tầng bộ máy ngầm (control plane + node components)
   API Server ← điểm vào duy nhất
   etcd       ← sổ cái lưu trạng thái
   Controller Manager ← vòng lặp tự sửa (self-healing)
   Scheduler  ← quyết định pod chạy ở node nào
   kubelet    ← quản đốc tại từng node, thật sự khởi động container
   kube-proxy ← thật sự thực thi load balancing
```

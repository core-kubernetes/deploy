# Các đối tượng bạn khai báo (Workload Objects)

Ẩn dụ xuyên suốt: **1 nhà hàng có nhiều chi nhánh**.

## 1. Node — "toà nhà"

Là 1 server vật lý/ảo (VPS). Cluster có 3 node = 3 toà nhà: `cp-1`, `worker-1`, `worker-2`.

- `cp-1` = **toà nhà quản lý** (văn phòng điều hành) — không phục vụ khách, chỉ ra quyết định
- `worker-1`, `worker-2` = **toà nhà chi nhánh thật sự phục vụ khách**

Mặc định `cp-1` bị **taint** (đánh dấu "cấm vào") nên không app nào được xếp chạy ở đó — tách riêng "não điều khiển" khỏi "nơi làm việc", tránh app ngốn tài nguyên làm sập khả năng quản lý cluster.

## 2. Pod — "1 nhân viên đang làm việc"

Đơn vị **nhỏ nhất** trong k8s. 1 Pod = 1 (hoặc vài) container chạy cùng nhau, có 1 IP nội bộ riêng.

**Đặc điểm quan trọng nhất: Pod là đồ dùng 1 lần.** Nó có thể chết bất cứ lúc nào (crash, hết RAM, node reboot) — và **tự nó không có khả năng tự hồi sinh**. Nếu chỉ tạo 1 Pod trần (không qua Deployment) rồi xoá nó → mất luôn, không ai tạo lại.

## 3. Deployment — "bản mô tả ca làm việc"

Deployment không trực tiếp là nhân viên — nó là **tờ giấy quy định**: *"tôi muốn LUÔN CÓ 3 nhân viên đứng ở quầy, dùng đúng công thức pha chế phiên bản X"*.

Deployment liên tục nhìn vào thực tế, so với tờ giấy này:

- Thiếu 1 người (Pod chết) → tự tuyển thêm (tạo Pod mới) — **self-healing**. Đã tự tay test: xoá pod `learn-api`, Deployment phát hiện thiếu → tạo pod mới ngay (field `requestCountOnThisPod` reset về 1 = bằng chứng pod mới hoàn toàn)
- Đổi công thức (đổi image) → cho nghỉ dần người cũ, tuyển người mới theo công thức mới — **rolling update**, không gián đoạn phục vụ
- Muốn nhiều/ít nhân viên hơn (`--replicas=N`) → **scale**

Deployment không trực tiếp tạo Pod — nó tạo ra lớp trung gian **ReplicaSet** (tên Pod có hậu tố như `learn-api-7f4c84ff44-...` — đó là tên ReplicaSet). ReplicaSet mới là thứ thật sự đếm và tạo Pod. Hiếm khi cần đụng trực tiếp vào ReplicaSet.

## 4. Service — "số điện thoại đặt bàn cố định"

Vấn đề: Pod có IP riêng, nhưng **IP đó đổi liên tục** (pod chết → pod mới có IP khác). Nếu khách nhớ IP cụ thể, IP đổi là gọi trớt quớt.

Service = **1 IP cố định, không bao giờ đổi** (ví dụ `10.98.115.123`). Khách gọi vào IP này, **kube-proxy** tự động nối tới **1 trong các Pod đang khoẻ mạnh** (round-robin) — khách không cần biết đang nói chuyện với Pod nào.

Đã test: gọi `https://be.emiu.site/` 10-15 lần → field `pod` trong response đổi qua lại giữa 3 pod, `node` đổi qua lại giữa `worker-1`/`worker-2` — chứng minh load balancing hoạt động thật.

## 5. Ingress — "lễ tân + bảo vệ cổng chính"

Service chỉ hoạt động **trong nội bộ toà nhà** — không hiểu tên miền (`be.emiu.site`), không tự làm SSL/HTTPS.

Ingress đứng ở **cổng chính duy nhất** nhìn ra Internet:

- Đọc tên miền khách gõ → dẫn tới đúng Service tương ứng
- Xử lý HTTPS/SSL (bắt tay với cert-manager để có chứng chỉ Let's Encrypt)
- Trong cluster này, Ingress **chỉ chạy trên `worker-1`** (do `nodeSelector`) — đó là lý do DNS trỏ về IP của `worker-1`, không phải `worker-2`

## 6. Namespace — "các tầng/khu vực riêng trong cùng toà nhà"

Không phải server riêng — chỉ là **ngăn cách logic**. `findsource` và `learn-k8s` dùng chung 3 node vật lý, nhưng tên tài nguyên (Pod, Service...) trong 2 namespace **không đụng nhau**. Đã test: xoá `api`/`mysql` trong `findsource`, `learn-k8s` không hề hấn gì.

## 7. Secret — "tủ đựng chìa khoá/giấy tờ mật"

Lưu thông tin nhạy cảm (password DB, token GHCR, private key SSL) — Pod đọc vào lúc chạy thay vì hardcode trong image. Đã dùng 2 loại: `ghcr-secret` (chìa khoá pull image từ GHCR) và `learn-tls`/`findsource-tls` (chứng chỉ SSL).

## 8. PVC / StatefulSet — "kho hàng không bị dọn khi nhân viên nghỉ" (chưa dùng ở lab hiện tại)

Pod bình thường **mất hết dữ liệu** khi bị xoá (đồ dùng 1 lần). MySQL cần dữ liệu **sống sót** qua việc pod chết/tạo lại → cần:

- **PersistentVolumeClaim (PVC)**: ổ đĩa gắn ngoài, tồn tại độc lập với vòng đời Pod
- **StatefulSet**: giống Deployment nhưng giữ định danh cố định, đúng thứ tự khởi động — quan trọng cho DB

Học lại phần này sau khi vững nền tảng — đúng kế hoạch giai đoạn 2.

## Tóm tắt 1 câu mỗi thành phần

| Thành phần | 1 câu |
|---|---|
| Node | Server vật lý chạy mọi thứ |
| Pod | 1 bản chạy của app — sống chết bất thường, tự nó không tự hồi sinh |
| Deployment | "Hợp đồng" giữ đúng số Pod, tự sửa khi lệch, cho phép scale/update |
| Service | Địa chỉ cố định + tự chia tải giữa các Pod |
| Ingress | Cổng vào từ Internet, hiểu domain + SSL |
| Namespace | Ngăn cách logic, không phải server riêng |
| Secret | Nơi giữ thông tin nhạy cảm cho Pod đọc |
| PVC / StatefulSet | Lưu trữ bền vững cho app cần nhớ dữ liệu (DB) |

Xem tiếp: [02-control-plane.md](./02-control-plane.md) — phần "bộ máy vận hành ngầm" bên dưới các đối tượng này.

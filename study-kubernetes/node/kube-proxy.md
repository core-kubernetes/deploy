# kube-proxy

## Định nghĩa

**kube-proxy** chạy trên **mỗi node**, duy trì **quy tắc mạng** để traffic tới **Service** được chuyển tới một trong các Pod backend.

> *"Maintains network rules on nodes to implement Services."* — **Optional** trên một số kiến trúc hiện đại.

---

## Service abstraction

```
Client trong cluster: http://api.findsource.svc:7003
        ↓
DNS (CoreDNS) → ClusterIP của Service "api"
        ↓
kube-proxy (hoặc CNI eBPF) → chọn Pod api-aaa hoặc api-bbb
        ↓
Pod IP:7003
```

User **không** cần biết IP Pod thay đổi khi restart — Service IP/DNS ổn định.

---

## Chế độ hoạt động (iptables / IPVS / nftables)

| Mode | Ý tưởng |
|------|---------|
| **iptables** | NAT rules — phổ biến, mặc định lịch sử |
| **IPVS** | Scale tốt hơn với nhiều Service |
| **nftables** | Thế hệ mới hơn trên kernel mới |

kube-proxy watch **Service** và **EndpointSlice**, cập nhật rules khi Pod thêm/bớt.

---

## Khi nào “optional”?

Một số CNI (Cilium, Calico eBPF) **thay thế** kube-proxy bằng dataplane trực tiếp — cluster có thể chạy **không** kube-proxy.

**kubeadm:** kube-proxy chạy dạng DaemonSet trong `kube-system`:

```bash
kubectl get pods -n kube-system | grep proxy
```

---

## Các loại Service liên quan

| Type | kube-proxy / cloud |
|------|-------------------|
| **ClusterIP** | NAT tới Pod IP (nội bộ cluster) |
| **NodePort** | Mở port trên mọi node |
| **LoadBalancer** | Thường cần cloud-controller-manager |
| **Headless** (`clusterIP: None`) | DNS trả về IP Pod trực tiếp — mysql StatefulSet |

Findsource Service `api`, `web`, `admin`, `mysql` — chủ yếu **ClusterIP**; Ingress trỏ vào Service.

---

## Ingress vs kube-proxy

| | Ingress | kube-proxy |
|---|---------|------------|
| Layer | HTTP/HTTPS host/path | Service IP → Pod |
| Chạy ở | Ingress Controller Pod | Mỗi node (hoặc CNI) |
| Findsource | `emiu.site` → Service web | `api:7003` → Pod api |

Luồng ngoài internet:

```
User → Ingress Controller → Service web:80 → kube-proxy → Pod web
```

---

## Debug networking

```bash
kubectl get svc -n findsource
kubectl get endpointslices -n findsource
kubectl run tmp --rm -it --image=busybox -- wget -qO- http://api.findsource:7003/process
```

Nếu Endpoints rỗng — Pod chưa Ready (readiness fail) hoặc selector sai label.

---

## Tài liệu tham khảo

- [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Virtual IPs and Service Proxies](https://kubernetes.io/docs/reference/networking/virtual-ips/)
- [kube-proxy](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/)

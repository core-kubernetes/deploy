# cloud-controller-manager (tuỳ chọn)

## Định nghĩa

**cloud-controller-manager** tích hợp Kubernetes với **nhà cung cấp cloud** (AWS, GCP, Azure, OpenStack…). Thành phần này **tách** khỏi `kube-controller-manager` để code cloud không nằm trong core Kubernetes.

> *"Integrates with underlying cloud provider(s)."* — **Optional**

---

## Các controller điển hình (cloud)

| Controller | Chức năng |
|------------|-----------|
| **Node** | Đăng ký node cloud, gán providerID, label zone |
| **Route** | Cấu hình route mạng cloud |
| **Service (LB)** | Tạo Load Balancer khi Service `type: LoadBalancer` |
| **Volume** | Gắn/detach disk cloud (EBS, PD…) |

```
Service type LoadBalancer
        ↓
cloud-controller-manager
        ↓
Cloud API → tạo ELB / GCP LB
        ↓
Cập nhật status.loadBalancer.ingress vào Service
```

---

## Bare metal / VPS (findsource)

Trên **VPS Viettel, VNCloud, Hetzner** không có cloud-controller-manager native:

| Tính năng cloud | Thay thế |
|-----------------|----------|
| LoadBalancer | **Ingress** (nginx) + NodePort, hoặc **MetalLB** |
| Disk động | Local PV, NFS, Longhorn, CSI driver |
| Node auto-repair | Giám sát ngoài K8s, thay VM thủ công |

Cluster findsource dùng **Ingress** (`deploy/k8s/base/ingress/ingress.yaml`) + **cert-manager**, không phụ thuộc CCM.

---

## Khi nào cần?

- EKS, GKE, AKS — nhà cung cấp vận hành CCM
- Tự cài kubeadm trên AWS — cài `aws-cloud-controller-manager`
- kubeadm trên VPS — **thường không** cài CCM

---

## Kiểm tra

```bash
kubectl get pods -n kube-system | grep cloud-controller
# Không có pod → cluster không dùng CCM (bình thường với kubeadm/VPS)
```

---

## Tài liệu tham khảo

- [Cloud Controller Manager](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)
- [Running Kubelet in Standalone Mode](https://kubernetes.io/docs/tasks/administer-cluster/running-kubernetes-cluster/)

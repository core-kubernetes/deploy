# Addons — Mở rộng chức năng cluster

**Addons** không phải core binary control plane, nhưng cluster **thực tế** cần chúng để vận hành: DNS, UI, metrics, logging tập trung.

> *"Addons extend the functionality of Kubernetes."* — [Components](https://kubernetes.io/docs/concepts/overview/components/)

Addons thường deploy dưới dạng **Pod** trong namespace `kube-system`, cài qua Helm hoặc manifest sau `kubeadm init`.

---

## DNS (bắt buộc thực tế)

| | |
|---|---|
| **Mục đích** | Phân giải tên Service/Pod **trong cluster** |
| **Triển khai phổ biến** | **CoreDNS** |
| **Ví dụ findsource** | `api.findsource.svc.cluster.local` → ClusterIP Service api |

```bash
kubectl get svc -n kube-system kube-dns
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Env app:**

```yaml
DB_HOST: mysql   # short name → mysql.findsource.svc
```

CoreDNS forward query ngoài internet (8.8.8.8) cho domain public.

Script findsource: [`../../k8s/scripts/04-install-addons.sh`](../../k8s/scripts/04-install-addons.sh)

---

## Web UI (Dashboard) — tuỳ chọn

| | |
|---|---|
| **Mục đích** | Giao diện web xem Pod, log, scale |
| **Lưu ý bảo mật** | Không expose public không auth; ưu tiên `kubectl` + RBAC |

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/...
kubectl proxy   # truy cập local
```

Production findsource: thường dùng **kubectl**, GitHub Actions, không phụ thuộc Dashboard.

---

## Container Resource Monitoring

| | |
|---|---|
| **Mục đích** | Thu thập CPU/RAM Pod, node — HPA, cảnh báo |
| **Ví dụ** | **metrics-server**, Prometheus, Datadog agent |

```bash
kubectl top nodes
kubectl top pods -n findsource
```

Cần **metrics-server** (addon) để `kubectl top` hoạt động.

**Horizontal Pod Autoscaler** cần metrics API:

```yaml
# HPA đọc CPU utilization từ metrics-server
```

---

## Cluster-level Logging

| | |
|---|---|
| **Mục đích** | Gom log container về kho tập trung |
| **Ví dụ** | EFK (Elasticsearch, Fluentd, Kibana), Loki, cloud logging |

Mặc định:

```bash
kubectl logs -n findsource deployment/api
```

→ kubelet đọc log từ container (local node). **Cluster logging** đưa log ra hệ thống ngoài (DaemonSet fluent-bit trên mỗi node).

---

## Addons findsource đã dùng / liên quan

| Addon / thành phần | File / script |
|--------------------|---------------|
| CoreDNS | Cài sẵn sau kubeadm + CNI |
| Ingress Controller | `04-install-addons.sh` (nginx/traefik) |
| cert-manager | `base/cert-manager/cluster-issuer.yaml` |
| cert-manager ≠ core | Operator Pod — cấp TLS Let's Encrypt |

Ingress + cert-manager **không** liệt kê trong trang Components nhưng là **addon pattern** thực tế cho HTTPS `emiu.site`.

---

## Cài addon

| Cách | Ví dụ |
|------|--------|
| Cài addon | Helm: ingress-nginx, cert-manager (findsource) |
| Manifest / Helm | cert-manager, metrics-server |
| GitOps | Argo CD apply chart |

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace
```

---

## Phân biệt Addon vs App

| | Addon | App (findsource) |
|---|-------|------------------|
| Phục vụ | Toàn cluster | Người dùng cuối |
| Namespace | `kube-system`, `ingress-nginx` | `findsource` |
| Ví dụ | CoreDNS, Ingress controller | api, web, mysql |

---

## Tài liệu tham khảo

- [Installing Addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Tools for Monitoring Resources](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)

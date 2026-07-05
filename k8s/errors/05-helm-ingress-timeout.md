# Helm ingress-nginx — `context deadline exceeded`

## Triệu chứng

```text
Release "ingress-nginx" does not exist. Installing it now.
Error: context deadline exceeded
```

## Nguyên nhân thường gặp (EC2 kubeadm)

1. **`LoadBalancer`** — không có cloud LB → Service `pending` mãi (script cũ).
2. **Admission webhook job** — pod/job `ingress-nginx-admission-*` fail hoặc chậm.
3. **Image pull chậm** — lần đầu pull image lớn từ registry.
4. **Pod Pending** — thiếu CPU/RAM hoặc nodeSelector sai.

## Chẩn đoán (trên cp-1)

```bash
kubectl get pods -n ingress-nginx -o wide
kubectl get jobs -n ingress-nginx
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp' | tail -20
kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller
```

| Pod status | Ý nghĩa |
|------------|---------|
| `ImagePullBackOff` | Node không pull được image — kiểm tra internet / SG outbound |
| `Pending` (pod mới) + pod cũ `Running` trên cùng worker-1 | **hostNetwork deadlock**: port 80/443 đã bị pod cũ chiếm — rolling update không thể hoàn tất. Pod cũ vẫn phục vụ traffic. Fix: `kubectl rollout undo deployment/ingress-nginx-controller -n ingress-nginx` |
| `Pending` (không có pod cũ) | Không schedule được — `kubectl describe pod` xem Events |
| `CrashLoopBackOff` | Port 80/443 bị chiếm trên node — `sudo ss -tlnp \| grep ':80\|:443'` trên worker-1 |
| Job `admission-*` Error | Dùng script mới (tắt admission webhook) |

## Fix — chạy lại script mới

Đồng bộ repo lên cp-1 (git pull hoặc scp), rồi:

```bash
cd ~/deploy/k8s
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
bash scripts/04-install-addons.sh
```

Script mới: `hostNetwork`, pin **worker-1**, `updateStrategy: Recreate` (tránh deadlock rolling update), tắt admission webhook, `kubectl rollout status` thay vì wait mọi pod cùng label.

## Fix tay (nếu vẫn lỗi)

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.dnsPolicy=ClusterFirstWithHostNet \
  --set controller.service.type=ClusterIP \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.nodeSelector."kubernetes\.io/hostname"=worker-1 \
  --wait=false

kubectl get pods -n ingress-nginx -w
```

## Thành công — Ingress đúng cấu hình

```bash
kubectl get pods -n ingress-nginx -o wide
```

```text
ingress-nginx-controller-...   1/1   Running   worker-1   172.31.23.25
```

- IP **172.31.23.25** = hostNetwork OK
- NODE **worker-1** = khớp DNS public IP

Kiểm tra port (từ cp-1, không cần `.pem` worker):

```bash
curl -I http://13.238.15.194
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- ss -tlnp | grep ':80'
```

**Không** chạy `ss` trên cp-1 — nginx không chạy trên control plane.

## Liên quan

- [../GETTING-STARTED.md](../GETTING-STARTED.md) Bước 9
- SG worker-1: TCP **80, 443** inbound

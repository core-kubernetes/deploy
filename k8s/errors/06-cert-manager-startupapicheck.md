# cert-manager — Helm `failed post-install` / `startupapicheck`

## Triệu chứng

```text
Error: failed post-install: 1 error occurred:
	* timed out waiting for the condition
```

Pod `cert-manager-startupapicheck-*` → `CrashLoopBackOff` / `Error`.

## Nguyên nhân

Job **startupapicheck** là hook Helm sau cài — kiểm tra webhook cert-manager. Trên cluster kubeadm nhỏ, job hay timeout dù 3 pod chính đã **Running**.

## Có sao không?

**Thường không sao** — nếu 3 pod sau đều Running:

```bash
kubectl get pods -n cert-manager
```

```text
cert-manager-...              1/1   Running
cert-manager-cainjector-...   1/1   Running
cert-manager-webhook-...      1/1   Running
```

→ Tiếp tục apply ClusterIssuer.

## Fix lần sau (cài lại / cluster mới)

```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --set startupapicheck.enabled=false \
  --wait=false
```

Script `04-install-addons.sh` đã tắt `startupapicheck`.

## Tiếp tục deploy

```bash
kubectl apply -f base/cert-manager/cluster-issuer.yaml
kubectl get clusterissuer letsencrypt-prod
```

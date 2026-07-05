# PVC Pending — `no storage class is set`

## Triệu chứng

```text
mysql-0     Pending
api-xxx     Pending

persistentvolumeclaim/mysql-data-mysql-0   Pending
persistentvolumeclaim/api-uploads          Pending

FailedBinding: no persistent volumes available for this claim and no storage class is set
```

## Nguyên nhân

Cluster **kubeadm trên EC2/VPS** không có cloud StorageClass (khác EKS/GKE). PVC cần **StorageClass** hoặc PV tạo tay.

**Không phải lỗi mạng** (Flannel/SG).

## Fix

```bash
cd ~/deploy/k8s
bash scripts/09-install-storage.sh
```

Xóa PVC/pod kẹt rồi deploy lại:

```bash
kubectl delete deployment api -n findsource --ignore-not-found
kubectl delete statefulset mysql -n findsource --ignore-not-found
kubectl delete pvc --all -n findsource

bash scripts/08-deploy-be.sh
```

## Kiểm tra

```bash
kubectl get storageclass
kubectl get pvc -n findsource
kubectl get pods -n findsource
```

PVC `Bound` → mysql-0 và api có thể schedule.

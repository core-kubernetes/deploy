#!/usr/bin/env bash
# Mở các port nội bộ VPC cần thiết cho kubeadm (API server, kubelet, etcd,
# controller-manager/scheduler, Flannel VXLAN) trên Security Group của cả
# 4 instance (control-plan, worker-1, worker-2, worker-3).
#
# Tự tra SG ID theo tag Name — không hardcode, chạy lại được dù instance
# bị relaunch (SG ID đổi) miễn tag Name giữ nguyên.
#
# Dùng: bash open-k8s-security-groups.sh
# Yêu cầu: đã `aws configure` / có quyền ec2:DescribeInstances + ec2:AuthorizeSecurityGroupIngress

set -euo pipefail

VPC_CIDR="172.31.0.0/16"
NAMES=("control-plan" "worker-1" "worker-2" "worker-3")

echo "Tra Security Group ID theo tag Name..."
SG_IDS=()
for name in "${NAMES[@]}"; do
  sg=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${name}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)
  if [[ "$sg" == "None" || -z "$sg" ]]; then
    echo "  ⚠️  Không tìm thấy instance đang chạy với tag Name=${name} — bỏ qua"
    continue
  fi
  echo "  ${name} -> ${sg}"
  SG_IDS+=("$sg")
done

if [[ ${#SG_IDS[@]} -eq 0 ]]; then
  echo "Không có SG nào để cấu hình. Kiểm tra lại instance có đang chạy không."
  exit 1
fi

echo
echo "Mở port nội bộ VPC (source ${VPC_CIDR}) trên ${#SG_IDS[@]} SG..."
for sg in "${SG_IDS[@]}"; do
  aws ec2 authorize-security-group-ingress --group-id "$sg" --ip-permissions \
    "IpProtocol=tcp,FromPort=6443,ToPort=6443,IpRanges=[{CidrIp=${VPC_CIDR}}]" \
    "IpProtocol=tcp,FromPort=10250,ToPort=10250,IpRanges=[{CidrIp=${VPC_CIDR}}]" \
    "IpProtocol=tcp,FromPort=2379,ToPort=2380,IpRanges=[{CidrIp=${VPC_CIDR}}]" \
    "IpProtocol=tcp,FromPort=10257,ToPort=10259,IpRanges=[{CidrIp=${VPC_CIDR}}]" \
    "IpProtocol=udp,FromPort=8472,ToPort=8472,IpRanges=[{CidrIp=${VPC_CIDR}}]" \
    2>&1 | grep -v "already exists" || true
done

echo
echo "Xong. Kiểm tra lại bằng: nc -zv <IP-private-cp-1> 6443 (chạy trên 1 worker)"
echo
echo "Riêng port 80/443 (DNS + Ingress, Bước 8 trong GETTING-STARTED.md) chỉ cần mở"
echo "trên SG của worker-1, source 0.0.0.0/0 — KHÔNG nằm trong script này, làm riêng:"
echo "  aws ec2 authorize-security-group-ingress --group-id <sg-worker-1> --ip-permissions \\"
echo "    'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]' \\"
echo "    'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]'"

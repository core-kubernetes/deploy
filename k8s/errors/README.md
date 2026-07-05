# K8s deploy — lỗi thường gặp & cách fix

Ghi lại lỗi thực tế khi dựng cluster **kubeadm** trên AWS EC2 (findsource / emiu.site).

Mỗi file = 1 lỗi: triệu chứng → nguyên nhân → cách sửa → cách tránh.

| # | Lỗi | File |
|---|-----|------|
| 1 | `NODE_IP: Set NODE_IP...` | [01-node-ip-not-set.md](./01-node-ip-not-set.md) |
| 2 | `conntrack not found in system path` | [02-conntrack-not-found.md](./02-conntrack-not-found.md) |
| 3 | Join: `context deadline exceeded` / `nc` timeout 6443 | [03-join-timeout-aws-security-group.md](./03-join-timeout-aws-security-group.md) |
| 4 | Laptop `kubectl` timeout tới `172.31.x.x:6443` | [04-kubectl-timeout-laptop-private-ip.md](./04-kubectl-timeout-laptop-private-ip.md) |
| 5 | Helm ingress: `context deadline exceeded` | [05-helm-ingress-timeout.md](./05-helm-ingress-timeout.md) |
| 6 | cert-manager: `failed post-install` / startupapicheck | [06-cert-manager-startupapicheck.md](./06-cert-manager-startupapicheck.md) |

Quay lại hướng dẫn triển khai: [../GETTING-STARTED.md](../GETTING-STARTED.md)

AWS Security Group chi tiết: [../../aws/ec2.md](../../aws/ec2.md)

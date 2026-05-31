1. truy cập -i

cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i control-plan-1.pem ubuntu@52.64.229.174
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-1.pem ubuntu@13.238.15.194
cd "/Users/khoi/Desktop/A (source)/fce/findsource/deploy/aws"
ssh -i worker-2.pem ubuntu@13.54.216.178

chmod 400 control-plan-1.pem

2. Tốt nhất: SSH Config + Terminal

Copy key:

mkdir -p ~/.ssh
cp control-plan-1.pem ~/.ssh/
chmod 400 ~/.ssh/control-plan-1.pem

Tạo:

nano ~/.ssh/config

Thêm:

Host aws-master
HostName 54.xxx.xxx.xxx
User ubuntu
IdentityFile ~/.ssh/control-plan-1.pem

Sau đó:

ssh aws-master

Ưu điểm:

Nhanh
Không cần nhớ IP
Không cần nhớ đường dẫn key
VS Code Remote SSH dùng được luôn
Quản lý 10-20 server vẫn ổn

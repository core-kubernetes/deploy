# Nginx + Certbot — Findsource

Hướng dẫn reverse proxy và HTTPS cho server deploy (`~/sources/app-core`).

---

## 1. Kiến trúc

```
Internet (HTTPS :443 / HTTP :80)
        │
        ▼
   Nginx (host)                    Docker containers
   /etc/nginx/                     ─────────────────
        │                          findsource-api  → :7003
        ├─ findsourcevn.com    ──► findsource-web  → :3000
        ├─ www → redirect      ──► findsource-admin → :5173
        ├─ be.findsourcevn.com ──►
        └─ admin.findsourcevn.com
```

| Domain | Service Docker | Port host |
|--------|----------------|-----------|
| `findsourcevn.com` | findsource-web | 3000 |
| `www.findsourcevn.com` | redirect → apex | — |
| `be.findsourcevn.com` | findsource-api | 7003 |
| `admin.findsourcevn.com` | findsource-admin | 5173 |

File config trong repo:

```
deploy/nginx/
  findsourcevn.conf   # 1 file gom 3 domain
  install.sh          # copy vào /etc/nginx/
```

---

## 2. DNS (bắt buộc trước Certbot)

Tại nhà cung cấp domain, thêm bản ghi **A** trỏ **IP public** của server:

| Type | Name | Value |
|------|------|-------|
| A | `@` | IP server (vd. `14.225.217.71`) |
| A | `www` | cùng IP |
| A | `be` | cùng IP |
| A | `admin` | cùng IP |

Kiểm tra (chờ 5–30 phút sau khi cấu hình):

```bash
# Trên Mac hoặc server
nslookup findsourcevn.com
nslookup www.findsourcevn.com
nslookup be.findsourcevn.com
nslookup admin.findsourcevn.com

dig +short findsourcevn.com A
```

IP trả về phải **trùng** IP public của server:

```bash
curl -4 ifconfig.me
```

---

## 3. Docker phải chạy trước Nginx

```bash
cd ~/sources/app-core

# DB (lần đầu)
docker compose -f db.yaml up -d

# App
docker compose -f 1.findsource.yml --env-file .env.develop up -d
docker ps
```

Test local trên server:

```bash
curl -I http://127.0.0.1:7003
curl -I http://127.0.0.1:3000
curl -I http://127.0.0.1:5173
```

---

## 4. Cài Nginx

```bash
sudo apt update
sudo apt install -y nginx

cd ~/sources/app-core/nginx
sudo bash install.sh
```

Script `install.sh` sẽ:

1. Copy `findsourcevn.conf` → `/etc/nginx/sites-available/findsourcevn.conf`
2. Symlink → `/etc/nginx/sites-enabled/findsourcevn.conf`
3. Xóa site `default` (nếu có)
4. `nginx -t` + `systemctl reload nginx`

**Vì sao copy vào `/etc/nginx/`?** Nginx chỉ đọc config từ `/etc/nginx/`, không đọc thư mục `~/sources/`.

Sửa config sau này:

```bash
nano ~/sources/app-core/nginx/findsourcevn.conf
cd ~/sources/app-core/nginx && sudo bash install.sh
```

Hoặc sửa trực tiếp:

```bash
sudo nano /etc/nginx/sites-available/findsourcevn.conf
sudo nginx -t
sudo systemctl reload nginx
```

Test HTTP qua domain (sau khi DNS OK):

```bash
curl -I http://findsourcevn.com
curl -I http://be.findsourcevn.com
curl -I http://admin.findsourcevn.com
```

---

## 5. Mở firewall (port 80 / 443)

Certbot cần Let's Encrypt truy cập **port 80** từ internet.

### UFW trên server

```bash
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

### Firewall panel VPS (Viettel, VNCloud, …)

Mở **Inbound**:

- TCP **80** — `0.0.0.0/0`
- TCP **443** — `0.0.0.0/0`

Test từ máy ngoài internet:

```bash
curl -I --connect-timeout 5 http://findsourcevn.com
```

Nếu **timeout** → firewall cloud hoặc IP DNS sai.

---

## 6. Certbot (HTTPS — Let's Encrypt)

### Cài Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Cấp certificate

```bash
# Web
sudo certbot --nginx -d findsourcevn.com -d www.findsourcevn.com

# API
sudo certbot --nginx -d be.findsourcevn.com

# Admin
sudo certbot --nginx -d admin.findsourcevn.com
```

Lần đầu: nhập email, đồng ý Terms of Service.

Certbot tự:

- Verify domain qua `http://domain/.well-known/acme-challenge/...`
- Thêm `listen 443 ssl` vào Nginx
- Cấu hình redirect HTTP → HTTPS (tuỳ chọn)

File cert sau khi cấp:

```
/etc/letsencrypt/live/findsourcevn.com/fullchain.pem
/etc/letsencrypt/live/findsourcevn.com/privkey.pem
```

### Gia hạn tự động

```bash
sudo certbot renew --dry-run
```

Timer systemd thường đã được cài sẵn cùng certbot.

---

## 7. Lỗi Certbot thường gặp

| Lỗi | Nguyên nhân | Cách xử lý |
|-----|-------------|------------|
| `no valid A records` / `NXDOMAIN` | DNS chưa trỏ hoặc chưa propagate | Thêm bản ghi A, chờ DNS |
| `Timeout during connect` / `firewall` | Port 80 chưa mở từ internet | UFW + firewall VPS, kiểm tra IP |
| `502 Bad Gateway` | Docker container chưa chạy | `docker ps`, start lại app |
| CORS API sau HTTPS | `FE_URLS` chưa có domain HTTPS | Sửa `.env.develop`, restart API |

---

## 8. Env sau khi có HTTPS

Trong `.env.develop` (rebuild FE + Admin, restart API):

```env
REACT_APP_API_BASE_URL=https://be.findsourcevn.com
VITE_API_BASE_URL=https://be.findsourcevn.com
FE_URLS=https://findsourcevn.com,https://www.findsourcevn.com,https://admin.findsourcevn.com
```

Rebuild / redeploy:

```bash
# Re-run GitHub Actions (FE, Admin, BE) hoặc trên server:
docker compose -f 1.findsource.yml --env-file .env.develop up -d --build web admin findsource-api
```

---

## 9. OpenSSL vs Certbot

| | Certbot (Let's Encrypt) | OpenSSL self-signed |
|---|------------------------|---------------------|
| Browser tin cậy | Có | Không (cảnh báo đỏ) |
| Server riêng + domain public | Khuyến nghị | Chỉ dev/test |
| Cert công ty (`host.crt` / `san.crt`) | Không dùng | Tạo CSR bằng OpenSSL, IT ký cert |

Với server riêng và domain thật → dùng **Certbot**, không dùng self-signed OpenSSL cho production.

---

## 10. Checklist hoàn tất

- [ ] DNS A record: `@`, `www`, `be`, `admin` → IP server
- [ ] `curl -4 ifconfig.me` = IP trong DNS
- [ ] Docker: mysql, api, web, admin đều Up
- [ ] `sudo bash install.sh` — Nginx OK (`nginx -t`)
- [ ] Port 80, 443 mở (UFW + panel VPS)
- [ ] `curl -I http://findsourcevn.com` không timeout
- [ ] Certbot cấp cert cho 4 domain
- [ ] https://findsourcevn.com, admin, be/api hoạt động
- [ ] Rebuild FE/Admin với URL HTTPS trong env

---

## 11. Lệnh nhanh (copy/paste)

```bash
# Nginx
cd ~/sources/app-core/nginx && sudo bash install.sh

# Certbot
sudo certbot --nginx -d findsourcevn.com -d www.findsourcevn.com
sudo certbot --nginx -d be.findsourcevn.com
sudo certbot --nginx -d admin.findsourcevn.com

# Kiểm tra
sudo nginx -t
sudo systemctl status nginx
docker ps
curl -I https://findsourcevn.com
```

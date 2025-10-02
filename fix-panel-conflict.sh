#!/bin/bash
# 패널 충돌 해결 스크립트

DOMAIN="pay.sasori.dev"

echo "===== Fix Panel Conflict ====="
echo ""

# 1. 다른 설정 파일 확인
echo "[1] Checking conflicting configs..."
echo ""
echo "Configs in /etc/nginx/conf.d/domains/:"
ls -la /etc/nginx/conf.d/domains/ 2>/dev/null

echo ""
echo "[2] Looking for domain configs..."
grep -r "pay.sasori.dev" /etc/nginx/conf.d/ 2>/dev/null
grep -r "pay.sasori.dev" /home/admin/conf/web/ 2>/dev/null

# 3. 기존 설정 백업 및 제거
echo ""
echo "[3] Backing up and removing old configs..."
sudo mv /etc/nginx/conf.d/pay.sasori.dev.conf /etc/nginx/conf.d/pay.sasori.dev.conf.bak 2>/dev/null

# 4. 패널의 기본 설정 확인
echo ""
echo "[4] Checking panel's default config..."
if [ -f "/home/admin/conf/web/pay.sasori.dev/nginx.conf" ]; then
    echo "Found panel config at: /home/admin/conf/web/pay.sasori.dev/nginx.conf"
    PANEL_CONFIG="/home/admin/conf/web/pay.sasori.dev/nginx.conf"
fi

# 5. 우선순위 높은 설정 생성
echo ""
echo "[5] Creating high priority config..."
sudo tee /etc/nginx/conf.d/00-$DOMAIN-ssl.conf << 'EOF'
# High priority SSL config for pay.sasori.dev
server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;

    # ACME challenge - 최우선 처리
    location ^~ /.well-known/acme-challenge/ {
        alias /var/www/certbot/.well-known/acme-challenge/;
        allow all;
        default_type "text/plain";
        try_files $uri =404;
    }

    # 나머지는 기본 처리
    location / {
        return 200 "Ready for SSL\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 6. 테스트 파일 재생성
echo ""
echo "[6] Recreating test files..."
sudo mkdir -p /var/www/certbot/.well-known/acme-challenge
echo "test-ssl-123" | sudo tee /var/www/certbot/.well-known/acme-challenge/test.txt
sudo chmod -R 755 /var/www/certbot

# 7. nginx 재시작
echo ""
echo "[7] Reloading nginx..."
sudo nginx -t
if [ $? -eq 0 ]; then
    sudo systemctl reload nginx
    echo "Nginx reloaded successfully"
else
    echo "Nginx config error!"
    exit 1
fi

# 8. 테스트
echo ""
echo "[8] Testing access..."
echo "Local test:"
curl -s http://localhost/.well-known/acme-challenge/test.txt

echo ""
echo "Domain test:"
curl -s http://$DOMAIN/.well-known/acme-challenge/test.txt

echo ""
echo "If you see 'test-ssl-123' above, proceed with certbot:"
echo ""
echo "sudo certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --agree-tos --email admin@$DOMAIN"
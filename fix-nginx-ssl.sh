#!/bin/bash
# Nginx 설정 수정 및 SSL 재시도

DOMAIN="pay.sasori.dev"

echo "===== Fixing Nginx Configuration ====="
echo ""

# Step 1: 현재 nginx 설정 확인
echo "[1] Checking current nginx configs..."
echo "Active configs:"
ls -la /etc/nginx/conf.d/
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "No sites-enabled directory"

# Step 2: 기존 설정 제거
echo ""
echo "[2] Cleaning old configs..."
sudo rm -f /etc/nginx/conf.d/default.conf
sudo rm -f /etc/nginx/conf.d/$DOMAIN.conf
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null
sudo rm -f /etc/nginx/sites-enabled/$DOMAIN 2>/dev/null

# Step 3: webroot 디렉토리 생성
echo ""
echo "[3] Creating webroot directory..."
sudo mkdir -p /var/www/certbot/.well-known/acme-challenge
sudo chmod -R 755 /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot

# 테스트 파일 생성
echo "test-file" | sudo tee /var/www/certbot/.well-known/acme-challenge/test.txt

# Step 4: 새로운 nginx 설정
echo ""
echo "[4] Creating new nginx config..."
sudo tee /etc/nginx/conf.d/$DOMAIN.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;

    # ACME challenge 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
        try_files $uri =404;
    }

    # 기본 응답
    location / {
        return 200 "Nginx OK - Ready for SSL\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Step 5: nginx 테스트 및 재시작
echo ""
echo "[5] Testing nginx config..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "Config OK. Reloading nginx..."
    sudo systemctl reload nginx
else
    echo "Config error! Check the configuration."
    exit 1
fi

# Step 6: 테스트 파일 접근 확인
echo ""
echo "[6] Testing ACME challenge path..."
echo "Local test:"
curl -I http://localhost/.well-known/acme-challenge/test.txt

echo ""
echo "External test (from domain):"
curl -I http://$DOMAIN/.well-known/acme-challenge/test.txt

# Step 7: Certbot 실행
echo ""
echo "===== Ready for SSL Certificate ====="
echo ""
echo "IMPORTANT: Make sure Cloudflare is in DNS-only mode!"
echo ""
read -p "Continue with certbot? (y/n): " CONTINUE

if [ "$CONTINUE" = "y" ]; then
    echo ""
    echo "[7] Running certbot..."
    sudo certbot certonly --webroot -w /var/www/certbot -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --debug
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "===== SUCCESS ====="
        echo "Certificate obtained! Now configuring HTTPS..."
        
        # HTTPS 설정 추가
        sudo tee /etc/nginx/conf.d/${DOMAIN}-ssl.conf << 'EOF'
# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;
    return 301 https://$host$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name pay.sasori.dev;

    ssl_certificate /etc/letsencrypt/live/pay.sasori.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.sasori.dev/privkey.pem;

    # Webhook proxy
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location / {
        return 200 "SSL Enabled - Webhook at /crypto-pay/webhook\n";
        add_header Content-Type text/plain;
    }
}
EOF
        
        # 기존 HTTP 설정 제거
        sudo rm /etc/nginx/conf.d/$DOMAIN.conf
        
        # nginx 재시작
        sudo nginx -t && sudo systemctl reload nginx
        
        echo ""
        echo "HTTPS configured!"
        echo "Test: https://$DOMAIN"
    else
        echo ""
        echo "===== FAILED ====="
        echo "Check /var/log/letsencrypt/letsencrypt.log for details"
    fi
else
    echo ""
    echo "Manual certbot command:"
    echo "sudo certbot certonly --webroot -w /var/www/certbot -d $DOMAIN"
fi
#!/bin/bash
# 웹 패널 환경에서 SSL 설정 스크립트

DOMAIN="pay.sasori.dev"

echo "===== SSL Setup with Control Panel ====="
echo ""
echo "Detected: Web hosting panel (Vesta/HestiaCP) is running"
echo "- Nginx on port 80 (proxy)"
echo "- Apache on port 8080 (backend)"
echo ""

# 1. 패널 확인
echo "[1] Checking control panel..."
if [ -d "/usr/local/vesta" ]; then
    echo "VestaCP detected"
    PANEL="vesta"
elif [ -d "/usr/local/hestia" ]; then
    echo "HestiaCP detected"
    PANEL="hestia"
else
    echo "Unknown panel, proceeding with manual config"
    PANEL="unknown"
fi

# 2. nginx 설정 디렉토리 찾기
echo ""
echo "[2] Finding nginx config directory..."
if [ -d "/home/admin/conf/web" ]; then
    echo "Panel nginx config found: /home/admin/conf/web"
    NGINX_CONF_DIR="/home/admin/conf/web/$DOMAIN"
elif [ -d "/etc/nginx/conf.d" ]; then
    echo "Using standard nginx conf.d"
    NGINX_CONF_DIR="/etc/nginx/conf.d"
else
    echo "Using default nginx conf.d"
    NGINX_CONF_DIR="/etc/nginx/conf.d"
fi

# 3. ACME challenge 설정 (패널 환경용)
echo ""
echo "[3] Setting up ACME challenge for panel environment..."

# 웹 루트 찾기
if [ -d "/home/admin/web/$DOMAIN/public_html" ]; then
    WEBROOT="/home/admin/web/$DOMAIN/public_html"
elif [ -d "/var/www/$DOMAIN" ]; then
    WEBROOT="/var/www/$DOMAIN"
else
    WEBROOT="/var/www/html"
fi

echo "Using webroot: $WEBROOT"

# ACME 디렉토리 생성
sudo mkdir -p $WEBROOT/.well-known/acme-challenge
echo "test-panel" | sudo tee $WEBROOT/.well-known/acme-challenge/test.txt

# 4. nginx include 설정 추가
echo ""
echo "[4] Adding nginx configuration..."

# 패널용 nginx 설정
sudo tee /etc/nginx/conf.d/ssl-$DOMAIN.conf << EOF
# SSL certificate validation for $DOMAIN
server {
    listen 80;
    server_name $DOMAIN;
    
    # ACME challenge
    location ^~ /.well-known/acme-challenge/ {
        root $WEBROOT;
        allow all;
        default_type "text/plain";
    }
    
    # Pass to backend (panel config)
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# 5. nginx 재시작
echo ""
echo "[5] Reloading nginx..."
sudo nginx -t && sudo systemctl reload nginx

# 6. 테스트
echo ""
echo "[6] Testing ACME path..."
curl -I http://$DOMAIN/.well-known/acme-challenge/test.txt

# 7. Certbot 실행
echo ""
echo "===== Getting SSL Certificate ====="
echo ""
read -p "Ready to get certificate? (y/n): " READY

if [ "$READY" = "y" ]; then
    echo ""
    echo "Running certbot..."
    sudo certbot certonly --webroot -w $WEBROOT -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "===== SUCCESS ====="
        echo "Certificate obtained!"
        echo ""
        echo "Certificate files:"
        echo "- /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        echo "- /etc/letsencrypt/live/$DOMAIN/privkey.pem"
        echo ""
        echo "Now add HTTPS configuration:"
        
        # HTTPS 설정 생성
        sudo tee /etc/nginx/conf.d/ssl-$DOMAIN-https.conf << EOF
# HTTPS configuration for $DOMAIN
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Webhook endpoint
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF
        
        # 기존 HTTP 설정 제거
        sudo rm -f /etc/nginx/conf.d/ssl-$DOMAIN.conf
        
        # nginx 재시작
        sudo nginx -t && sudo systemctl reload nginx
        
        echo ""
        echo "HTTPS enabled!"
        echo "Test: https://$DOMAIN"
        echo "Webhook: https://$DOMAIN/crypto-pay/webhook"
    else
        echo ""
        echo "Certificate generation failed!"
        echo "Check if Cloudflare is in DNS-only mode"
    fi
fi
#!/bin/bash
# 간단한 SSL 설정 스크립트 - 단계별 실행

DOMAIN="pay.sasori.dev"
echo "===== SSL Setup for $DOMAIN ====="
echo ""

# Step 1: nginx 설치 확인
echo "[Step 1] Checking nginx..."
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    sudo apt update
    sudo apt install -y nginx
fi
sudo systemctl start nginx
echo "nginx is running"

# Step 2: certbot 설치
echo ""
echo "[Step 2] Installing certbot..."
sudo apt install -y certbot python3-certbot-nginx

# Step 3: nginx 기본 설정
echo ""
echo "[Step 3] Creating nginx config..."
sudo tee /etc/nginx/conf.d/$DOMAIN.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        return 200 "Ready for SSL";
        add_header Content-Type text/plain;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

# Step 4: nginx 재시작
echo ""
echo "[Step 4] Restarting nginx..."
sudo nginx -t && sudo systemctl reload nginx

# Step 5: 방화벽 설정
echo ""
echo "[Step 5] Opening firewall ports..."
sudo ufw allow 80/tcp 2>/dev/null || true
sudo ufw allow 443/tcp 2>/dev/null || true

# Step 6: SSL 인증서 발급
echo ""
echo "===== IMPORTANT ====="
echo "Before continuing, make sure:"
echo "1. Cloudflare is in DNS-only mode (GREY cloud, not ORANGE)"
echo "2. Domain points to this server"
echo ""
read -p "Ready to get SSL certificate? (y/n): " READY

if [ "$READY" = "y" ]; then
    echo ""
    echo "[Step 6] Getting SSL certificate..."
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "===== SUCCESS ====="
        echo "SSL certificate installed!"
        echo "Visit: https://$DOMAIN"
    else
        echo ""
        echo "===== FAILED ====="
        echo "SSL certificate installation failed."
        echo ""
        echo "Try manual mode:"
        echo "sudo certbot --nginx -d $DOMAIN"
    fi
else
    echo ""
    echo "Skipped SSL certificate. Run this command when ready:"
    echo "sudo certbot --nginx -d $DOMAIN"
fi
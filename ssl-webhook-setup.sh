#!/bin/bash
# SSL + Webhook 설정 스크립트

DOMAIN="pay.sasori.dev"
WEBHOOK_PORT="8080"

echo "===== SSL + Webhook Setup ====="
echo "Domain: $DOMAIN"
echo "Webhook Port: $WEBHOOK_PORT"
echo ""

# Step 1: 기본 설정
echo "[1] Installing packages..."
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Step 2: 디렉토리 생성
echo "[2] Creating directories..."
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html

# Step 3: HTTP 설정 (SSL 발급용)
echo "[3] Creating HTTP config for SSL..."
sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name pay.sasori.dev;
    
    root /var/www/html;
    
    location /.well-known/acme-challenge/ {
        allow all;
    }
    
    location / {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF

# Step 4: nginx 시작
echo "[4] Starting nginx..."
sudo nginx -t && sudo systemctl reload nginx

# Step 5: SSL 인증서 발급
echo ""
echo "===== SSL Certificate ====="
echo "IMPORTANT: Cloudflare must be in DNS-only mode!"
echo ""
echo "Getting SSL certificate..."
sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# Step 6: HTTPS + Webhook 설정
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "[6] Configuring HTTPS with webhook..."
    
    sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << EOF
# HTTP redirect
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Webhook endpoint
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:$WEBHOOK_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    
    # Health check
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
    
    # Root
    location / {
        return 200 "Webhook server running";
        add_header Content-Type text/plain;
    }
}
EOF

    sudo nginx -t && sudo systemctl reload nginx
    
    echo ""
    echo "===== SUCCESS ====="
    echo "HTTPS: https://$DOMAIN"
    echo "Webhook: https://$DOMAIN/crypto-pay/webhook"
    echo "Health: https://$DOMAIN/health"
    
else
    echo ""
    echo "===== FAILED ====="
    echo "SSL certificate not found!"
    echo ""
    echo "Check Cloudflare settings:"
    echo "1. Must be DNS-only mode (grey cloud)"
    echo "2. Wait 5 minutes for DNS propagation"
    echo "3. Try again: sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN"
fi
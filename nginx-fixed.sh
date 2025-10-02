#!/bin/bash
DOMAIN="pay.sasori.dev"
APP_PORT="8080"

echo "===== Nginx SSL Setup ====="
echo "Domain: $DOMAIN"
echo "Port: $APP_PORT"
echo ""

# Step 1: Install nginx and certbot
echo "[1] Installing nginx and certbot"
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx curl

# Step 2: Create nginx directories if they don't exist
echo "[2] Creating nginx directories"
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled
sudo mkdir -p /etc/nginx/conf.d

# Step 3: Check nginx installation
echo "[3] Checking nginx status"
nginx -v
sudo systemctl status nginx --no-pager || sudo systemctl start nginx

# Step 4: Clean old configs
echo "[4] Cleaning old configs"
sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-enabled/$DOMAIN
sudo rm -f /etc/nginx/conf.d/pay.conf
sudo rm -f /etc/nginx/conf.d/default.conf

# Step 5: Create webroot
echo "[5] Creating webroot directory"
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html
echo "test-file" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt

# Step 6: Use conf.d directory instead (more reliable)
echo "[6] Creating nginx config in conf.d"
sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/html;

    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
    }

    location / {
        return 200 "Nginx OK";
        add_header Content-Type text/plain;
    }
}
EOF

# Step 7: Test and reload nginx
echo "[7] Testing nginx configuration"
sudo nginx -t
if [ $? -eq 0 ]; then
    sudo systemctl reload nginx
    echo "Nginx reloaded successfully"
else
    echo "Nginx config error!"
    exit 1
fi

# Step 8: Test HTTP access
echo "[8] Testing HTTP access"
sleep 2
curl -I http://$DOMAIN/.well-known/acme-challenge/test.txt

# Step 9: Open firewall ports
echo "[9] Opening firewall ports"
sudo ufw allow 80/tcp 2>/dev/null || echo "Port 80 opened"
sudo ufw allow 443/tcp 2>/dev/null || echo "Port 443 opened"
sudo ufw allow 'Nginx Full' 2>/dev/null || echo "Nginx Full allowed"

# Step 10: Get SSL certificate
echo "[10] Getting SSL certificate"
echo "IMPORTANT: Make sure Cloudflare is in DNS-only mode (grey cloud)!"
echo ""

sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# Step 11: Configure HTTPS if certificate obtained
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "[11] Configuring HTTPS"

    sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Webhook proxy
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }

    # Default page
    location / {
        return 200 "SSL Enabled - Webhook at /crypto-pay/webhook";
        add_header Content-Type text/plain;
    }
}
EOF

    # Reload nginx
    sudo nginx -t && sudo systemctl reload nginx

    echo ""
    echo "===== SUCCESS ====="
    echo "HTTPS: https://$DOMAIN/"
    echo "Webhook: https://$DOMAIN/crypto-pay/webhook"
    echo "Health: https://$DOMAIN/health"
    echo ""
    echo "Test commands:"
    echo "curl https://$DOMAIN/health"
    echo "curl -X POST https://$DOMAIN/crypto-pay/webhook -H 'Content-Type: application/json' -d '{\"test\":true}'"

else
    echo ""
    echo "===== SSL FAILED ====="
    echo "Troubleshooting steps:"
    echo "1. Make sure Cloudflare is in DNS-only mode (grey cloud, not orange)"
    echo "2. Check if domain points to this server:"
    echo "   dig $DOMAIN"
    echo "3. Check nginx error log:"
    echo "   sudo tail -f /var/log/nginx/error.log"
    echo "4. Try manual certificate:"
    echo "   sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN"
fi
#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"
APP_PORT="${APP_PORT:-8080}"

echo "SSL Setup Script"
echo "================================"
echo "Domain: ${DOMAIN}"
echo "App Port: ${APP_PORT}"
echo ""

# 1. Install packages
echo "[1/10] Installing required packages"
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx curl dnsutils

# 2. Check DNS
echo "[2/10] Checking DNS settings"
DOMAIN_IP=$(dig +short ${DOMAIN} | head -1)
SERVER_IP=$(curl -s ifconfig.me)
echo "Domain IP: ${DOMAIN_IP}"
echo "Server IP: ${SERVER_IP}"

if [ "${DOMAIN_IP}" != "${SERVER_IP}" ]; then
    echo "WARNING: Domain does not point to server IP!"
    echo "If using Cloudflare, set to DNS only mode (grey cloud)."
fi

# 3. Clean existing nginx configs
echo "[3/10] Cleaning existing nginx configurations"
for conf in /etc/nginx/sites-enabled/default /etc/nginx/conf.d/pay.conf /etc/nginx/sites-available/${DOMAIN}; do
    if [ -f "$conf" ]; then
        sudo mv "$conf" "${conf}.bak-$(date +%Y%m%d)" 2>/dev/null || true
        echo "Backed up: ${conf}"
    fi
done

if [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi
if [ -L /etc/nginx/sites-enabled/${DOMAIN} ]; then
    sudo rm /etc/nginx/sites-enabled/${DOMAIN}
fi

# 4. Create webroot directory
echo "[4/10] Setting up webroot directory"
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

echo "acme-test-$(date +%s)" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt > /dev/null

# 5. Create HTTP nginx config
echo "[5/10] Creating HTTP nginx configuration"
sudo tee /etc/nginx/sites-available/${DOMAIN}-http > /dev/null <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    root /var/www/html;
    index index.html index.htm;

    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    access_log /var/log/nginx/DOMAIN_PLACEHOLDER-access.log;
    error_log /var/log/nginx/DOMAIN_PLACEHOLDER-error.log debug;
}
EOF

sudo sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" /etc/nginx/sites-available/${DOMAIN}-http

# 6. Enable nginx config
echo "[6/10] Enabling nginx configuration"
sudo ln -sf /etc/nginx/sites-available/${DOMAIN}-http /etc/nginx/sites-enabled/

if sudo nginx -t; then
    echo "Nginx configuration valid"
    sudo systemctl reload nginx
else
    echo "Nginx configuration error!"
    exit 1
fi

# 7. Test HTTP access
echo "[7/10] Testing HTTP access"
sleep 2
HTTP_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://${DOMAIN}/.well-known/acme-challenge/test.txt || echo "000")
if [ "$HTTP_TEST" = "200" ]; then
    echo "HTTP access successful"
else
    echo "HTTP access failed (code: $HTTP_TEST)"
    echo "Checking nginx logs:"
    sudo tail -n 20 /var/log/nginx/${DOMAIN}-error.log
fi

# 8. Configure firewall
echo "[8/10] Configuring firewall"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 'Nginx Full'
    echo "Firewall ports opened"
fi

# 9. Request SSL certificate
echo "[9/10] Requesting SSL certificate"
echo "IMPORTANT: If using Cloudflare, ensure DNS only mode (grey cloud) is enabled!"
echo ""

if sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}; then
    echo "SSL certificate issued successfully!"

    # 10. Apply HTTPS configuration
    echo "[10/10] Applying HTTPS configuration"

    sudo tee /etc/nginx/sites-available/${DOMAIN} > /dev/null <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;

    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256";

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    client_max_body_size 10m;
    keepalive_timeout 30s;

    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:APP_PORT_PLACEHOLDER;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        access_log /var/log/nginx/DOMAIN_PLACEHOLDER-webhook.log;
        error_log /var/log/nginx/DOMAIN_PLACEHOLDER-webhook-error.log;
    }

    location /health {
        access_log off;
        default_type text/plain;
        return 200 "OK";
    }

    location / {
        default_type text/html;
        return 200 '<html><body><h1>SSL Enabled</h1><p>Webhook: /crypto-pay/webhook</p></body></html>';
    }

    access_log /var/log/nginx/DOMAIN_PLACEHOLDER-access.log;
    error_log /var/log/nginx/DOMAIN_PLACEHOLDER-error.log;
}
EOF

    sudo sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" /etc/nginx/sites-available/${DOMAIN}
    sudo sed -i "s/APP_PORT_PLACEHOLDER/${APP_PORT}/g" /etc/nginx/sites-available/${DOMAIN}

    sudo rm /etc/nginx/sites-enabled/${DOMAIN}-http
    sudo ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

    sudo nginx -t && sudo systemctl reload nginx

    echo ""
    echo "Setup Complete!"
    echo "================================"
    echo "SSL certificate: Active"
    echo "HTTPS: https://${DOMAIN}/"
    echo "Webhook: https://${DOMAIN}/crypto-pay/webhook"
    echo "Proxy: 127.0.0.1:${APP_PORT}"
    echo ""
    echo "Test commands:"
    echo "curl -i https://${DOMAIN}/"
    echo "curl -i https://${DOMAIN}/health"
    echo "curl -X POST https://${DOMAIN}/crypto-pay/webhook -H 'Content-Type: application/json' -d '{\"test\":true}'"

else
    echo "SSL certificate issuance failed!"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check Cloudflare DNS only mode (grey cloud)"
    echo "2. Verify domain DNS A record"
    echo "3. Check firewall ports 80, 443 are open"
    echo ""
    echo "Manual test:"
    echo "curl -v http://${DOMAIN}/.well-known/acme-challenge/test.txt"
    echo ""
    echo "Check nginx logs:"
    echo "sudo tail -f /var/log/nginx/${DOMAIN}-error.log"
    echo ""
    echo "To retry:"
    echo "sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN}"
fi
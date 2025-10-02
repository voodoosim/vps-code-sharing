#!/bin/bash
DOMAIN="pay.sasori.dev"
APP_PORT="8080"

echo "===== SSL Setup Script ====="
echo "Domain: $DOMAIN"
echo "Port: $APP_PORT"
echo ""

# Step 1
echo "[Step 1] Update and install packages"
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx curl dnsutils

# Step 2
echo "[Step 2] Clean old nginx configs"
sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-enabled/$DOMAIN
sudo rm -f /etc/nginx/conf.d/pay.conf

# Step 3
echo "[Step 3] Create webroot"
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html
echo "test" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt

# Step 4
echo "[Step 4] Create nginx HTTP config"
cat <<EOF | sudo tee /etc/nginx/sites-available/http-$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;

    location /.well-known/acme-challenge/ {
        allow all;
    }

    location / {
        return 200 "OK";
    }
}
EOF

# Step 5
echo "[Step 5] Enable nginx config"
sudo ln -sf /etc/nginx/sites-available/http-$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Step 6
echo "[Step 6] Test HTTP"
curl -s http://$DOMAIN/.well-known/acme-challenge/test.txt

# Step 7
echo "[Step 7] Open firewall"
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Step 8
echo "[Step 8] Get SSL certificate"
echo "NOTE: Cloudflare must be in DNS-only mode"
sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# Step 9
echo "[Step 9] Create HTTPS config"
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
cat <<EOF | sudo tee /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /health {
        return 200 "OK";
    }

    location / {
        return 200 "SSL OK";
    }
}
EOF

    sudo rm -f /etc/nginx/sites-enabled/http-$DOMAIN
    sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx

    echo ""
    echo "===== SUCCESS ====="
    echo "HTTPS: https://$DOMAIN/"
    echo "Webhook: https://$DOMAIN/crypto-pay/webhook"
    echo "Test: curl https://$DOMAIN/health"
else
    echo ""
    echo "===== FAILED ====="
    echo "1. Check Cloudflare DNS-only mode"
    echo "2. Check domain points to server"
    echo "3. Manual retry: sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN"
fi
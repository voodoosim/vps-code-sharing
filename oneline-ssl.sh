#!/bin/bash
# 한 줄 명령어로 실행 가능한 버전
# VPS에서 이 명령어만 복사-붙여넣기 하세요:
# bash <(curl -fsSL https://raw.githubusercontent.com/voodoosim/vps-code-sharing/main/oneline-ssl.sh)

DOMAIN="pay.sasori.dev" && APP_PORT="8080" && \
sudo apt update && sudo apt install -y nginx certbot python3-certbot-nginx curl dnsutils dos2unix && \
sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/$DOMAIN /etc/nginx/conf.d/pay.conf && \
sudo mkdir -p /var/www/html/.well-known/acme-challenge && \
sudo chown -R www-data:www-data /var/www/html && \
echo "test" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt > /dev/null && \
echo "server { listen 80; server_name $DOMAIN; root /var/www/html; location /.well-known/acme-challenge/ { allow all; } location / { return 200 'OK'; } }" | sudo tee /etc/nginx/sites-available/http-$DOMAIN > /dev/null && \
sudo ln -sf /etc/nginx/sites-available/http-$DOMAIN /etc/nginx/sites-enabled/ && \
sudo nginx -t && sudo systemctl reload nginx && \
sudo ufw allow 80/tcp && sudo ufw allow 443/tcp && \
echo "Requesting SSL certificate..." && \
sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN && \
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then \
echo "server { listen 80; server_name $DOMAIN; return 301 https://\$host\$request_uri; } server { listen 443 ssl http2; server_name $DOMAIN; ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem; location /crypto-pay/webhook { proxy_pass http://127.0.0.1:$APP_PORT; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto https; } location /health { return 200 'OK'; } location / { return 200 'SSL OK'; } }" | sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null && \
sudo rm -f /etc/nginx/sites-enabled/http-$DOMAIN && \
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/ && \
sudo nginx -t && sudo systemctl reload nginx && \
echo "SUCCESS - HTTPS enabled at https://$DOMAIN/"; \
else \
echo "FAILED - Check Cloudflare DNS-only mode"; \
fi
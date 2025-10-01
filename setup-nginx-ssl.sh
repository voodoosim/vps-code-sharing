#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"
APP_PORT="${APP_PORT:-8080}"

echo "[1/6] Install nginx (if missing)"
if ! command -v nginx >/dev/null 2>&1; then
apt update && apt install -y nginx
fi

echo "[2/6] Open firewall (if ufw present)"
if command -v ufw >/dev/null 2>&1; then
ufw allow "Nginx Full" 2>/dev/null || { ufw allow 80/tcp; ufw allow 443/tcp; }
fi

echo "[3/6] Write minimal HTTP vhost for ${DOMAIN}"
mkdir -p /etc/nginx/conf.d
cat >/etc/nginx/conf.d/pay.conf <<CONF
server {
listen 80;
server_name ${DOMAIN};
location / { default_type text/plain; return 200 "OK"; }
}
CONF
nginx -t && systemctl reload nginx

echo "[4/6] Install certbot and request certificate (Cloudflare는 DNS only/회색 구름 필수)"
if ! command -v certbot >/dev/null 2>&1; then
apt install -y certbot python3-certbot-nginx
fi
certbot --nginx -d "${DOMAIN}" --redirect || true

echo "[5/6] If certificate exists, write HTTPS vhost with webhook proxy"
if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]; then
cat >/etc/nginx/conf.d/pay.conf <<'CONF'
server {
listen 80;
server_name DOMAIN_PLACEHOLDER;
return 301 https://$host$request_uri;
}
server {
listen 443 ssl http2;
server_name DOMAIN_PLACEHOLDER;
ssl_certificate     /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
client_max_body_size 5m;
keepalive_timeout 30s;
location /crypto-pay/webhook {
proxy_pass         http://127.0.0.1:APP_PORT_PLACEHOLDER;
proxy_set_header   Host $host;
proxy_set_header   X-Real-IP $remote_addr;
proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header   X-Forwarded-Proto https;
}
}
CONF
sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" /etc/nginx/conf.d/pay.conf
sed -i "s/APP_PORT_PLACEHOLDER/${APP_PORT}/g" /etc/nginx/conf.d/pay.conf
nginx -t && systemctl reload nginx
else
echo "(!) Certificate not found. If certbot failed, switch Cloudflare to DNS only and run:"
echo "    certbot --nginx -d ${DOMAIN} --redirect"
echo "Then re-run this script."
fi

echo "[6/6] Done."
echo "Test webhook (앱이 127.0.0.1:${APP_PORT}에서 POST /crypto-pay/webhook 처리 중이어야 함):"
echo "curl -i -X POST https://${DOMAIN}/crypto-pay/webhook -H 'Content-Type: application/json' -d '{\"ping\":true}'"
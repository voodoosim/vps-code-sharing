#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"
APP_PORT="${APP_PORT:-8080}"

echo "🔧 Webhook 설정 추가 스크립트"
echo "================================"

if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "❌ SSL 인증서를 먼저 발급받으세요!"
    exit 1
fi

echo "[1] Webhook 설정 추가"

# Nginx 설정 파일 업데이트
sudo tee /etc/nginx/sites-available/${DOMAIN} > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # 보안 헤더
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 10m;
    keepalive_timeout 30s;

    # Crypto Payment Webhook
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        # 타임아웃 설정
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        # 버퍼 설정
        proxy_buffering off;
        proxy_request_buffering off;

        # 로깅
        access_log /var/log/nginx/${DOMAIN}-webhook.log;
        error_log /var/log/nginx/${DOMAIN}-webhook-error.log;
    }

    # 헬스체크
    location /health {
        access_log off;
        default_type text/plain;
        return 200 "OK";
    }

    # 기본 페이지
    location / {
        root /var/www/html;
        index index.html;

        # 파일이 없으면 상태 페이지 표시
        error_page 404 = @status;
    }

    location @status {
        default_type text/html;
        return 200 '<!DOCTYPE html>
<html>
<head>
    <title>${DOMAIN}</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .status { color: green; font-weight: bold; }
        .endpoint { background: #f0f0f0; padding: 10px; border-radius: 5px; margin: 10px 0; }
        code { background: #333; color: #fff; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>🔐 ${DOMAIN}</h1>
    <p class="status">✅ SSL Enabled & Active</p>

    <div class="endpoint">
        <h3>Webhook Endpoint</h3>
        <p><code>POST https://${DOMAIN}/crypto-pay/webhook</code></p>
        <p>Proxy Target: <code>127.0.0.1:${APP_PORT}</code></p>
    </div>

    <div class="endpoint">
        <h3>Test Commands</h3>
        <pre>curl -X POST https://${DOMAIN}/crypto-pay/webhook \\
  -H "Content-Type: application/json" \\
  -d "{\\"test\\": true}"</pre>
    </div>

    <div class="endpoint">
        <h3>Logs</h3>
        <p>Access: <code>/var/log/nginx/${DOMAIN}-webhook.log</code></p>
        <p>Errors: <code>/var/log/nginx/${DOMAIN}-webhook-error.log</code></p>
    </div>
</body>
</html>';
    }
}
EOF

echo "[2] Nginx 설정 테스트"
sudo nginx -t

echo "[3] Nginx 재시작"
sudo systemctl reload nginx

echo ""
echo "✅ 설정 완료!"
echo "================================"
echo "🔐 HTTPS: https://${DOMAIN}/"
echo "🔗 Webhook: https://${DOMAIN}/crypto-pay/webhook"
echo "🎯 Target: 127.0.0.1:${APP_PORT}"
echo ""
echo "📝 테스트:"
echo "curl -i https://${DOMAIN}/"
echo "curl -X POST https://${DOMAIN}/crypto-pay/webhook -H 'Content-Type: application/json' -d '{\"test\":true}'"
echo ""
echo "📊 로그 확인:"
echo "tail -f /var/log/nginx/${DOMAIN}-webhook.log"
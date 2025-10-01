#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"
APP_PORT="${APP_PORT:-8080}"

echo "🔧 SSL 설정 수정 스크립트"
echo "================================"

echo "[1/5] certbot nginx 플러그인 설치"
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

echo "[2/5] 기존 nginx 설정 백업 및 정리"
if [ -f /etc/nginx/conf.d/pay.conf ]; then
    sudo mv /etc/nginx/conf.d/pay.conf /etc/nginx/conf.d/pay.conf.bak
    echo "✅ 기존 설정 백업됨: /etc/nginx/conf.d/pay.conf.bak"
fi

echo "[3/5] HTTP 기본 설정 생성"
sudo tee /etc/nginx/conf.d/pay.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location / {
        default_type text/plain;
        return 200 "SSL Setup in Progress";
    }
}
EOF

echo "[4/5] Nginx 설정 테스트 및 재시작"
sudo nginx -t && sudo systemctl reload nginx

echo "[5/5] Let's Encrypt SSL 인증서 발급"
echo "⚠️  중요: Cloudflare를 사용중이라면 DNS only 모드(회색 구름)로 설정하세요!"
echo ""
sudo certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email admin@${DOMAIN} --redirect

# 인증서 발급 성공 여부 확인
if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo ""
    echo "✅ SSL 인증서 발급 성공! HTTPS 설정 적용중..."

    # HTTPS 설정으로 업데이트
    sudo tee /etc/nginx/conf.d/pay.conf > /dev/null <<EOF
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

    # SSL 최적화
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384";

    # 보안 헤더
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    client_max_body_size 5m;
    keepalive_timeout 30s;

    # Webhook 엔드포인트
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 30s;
        proxy_connect_timeout 10s;
    }

    # 기본 페이지
    location / {
        default_type text/html;
        return 200 '<html><body><h1>✅ SSL Setup Complete</h1><p>Webhook endpoint: /crypto-pay/webhook</p></body></html>';
        add_header Content-Type text/html;
    }
}
EOF

    sudo nginx -t && sudo systemctl reload nginx

    echo ""
    echo "🎉 완료!"
    echo "================================"
    echo "✅ SSL 인증서 설치 완료"
    echo "✅ HTTPS 리다이렉트 설정 완료"
    echo "✅ Webhook 프록시 설정 완료: https://${DOMAIN}/crypto-pay/webhook → 127.0.0.1:${APP_PORT}"
    echo ""
    echo "📝 테스트 명령어:"
    echo "curl -i https://${DOMAIN}/"
    echo "curl -i -X POST https://${DOMAIN}/crypto-pay/webhook -H 'Content-Type: application/json' -d '{\"ping\":true}'"

else
    echo ""
    echo "❌ SSL 인증서 발급 실패!"
    echo "================================"
    echo "해결 방법:"
    echo "1. Cloudflare를 사용중이라면 DNS only 모드(회색 구름)로 변경"
    echo "2. 도메인 A 레코드가 서버 IP를 가리키는지 확인"
    echo "3. 수동으로 인증서 발급 시도:"
    echo "   sudo certbot --nginx -d ${DOMAIN} --redirect"
    echo ""
    echo "4. 인증서 발급 후 이 스크립트를 다시 실행하세요"
fi
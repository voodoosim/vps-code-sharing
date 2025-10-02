#!/bin/bash
# Let's Encrypt SSL 강제 적용

echo "===== Let's Encrypt SSL 강제 적용 ====="
echo ""

# 1. 모든 pay.sasori.dev 설정 확인
echo "[1] 기존 설정 확인 및 백업..."
sudo mkdir -p /etc/nginx/backup
sudo cp /etc/nginx/conf.d/*.conf /etc/nginx/backup/ 2>/dev/null
echo "백업 완료: /etc/nginx/backup/"
echo ""

# 2. 우선순위 높은 설정 생성 (00- prefix로 먼저 로드되도록)
echo "[2] 우선순위 높은 SSL 설정 생성..."

sudo tee /etc/nginx/conf.d/00-pay-sasori-priority.conf > /dev/null << 'EOF'
# Priority SSL Configuration for pay.sasori.dev
# This must load before any default configurations

server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name pay.sasori.dev;

    # Let's Encrypt 인증서
    ssl_certificate /etc/letsencrypt/live/pay.sasori.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.sasori.dev/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Webhook 프록시 설정
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080/crypto-pay/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # 로그
        access_log /var/log/nginx/webhook-access.log;
        error_log /var/log/nginx/webhook-error.log debug;

        # 디버그를 위한 응답
        proxy_intercept_errors off;
    }

    # 테스트 엔드포인트
    location /test {
        return 200 "SSL OK - pay.sasori.dev\n";
        add_header Content-Type text/plain;
    }

    # 루트
    location / {
        return 200 "HTTPS Active\nWebhook: https://pay.sasori.dev/crypto-pay/webhook\nTest: https://pay.sasori.dev/test\n";
        add_header Content-Type text/plain;
    }

    # 보안 헤더
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Custom-Server "pay.sasori.dev" always;

    access_log /var/log/nginx/pay-sasori-ssl-access.log;
    error_log /var/log/nginx/pay-sasori-ssl-error.log;
}
EOF

# 3. 충돌하는 다른 설정 제거
echo ""
echo "[3] 충돌 설정 제거..."
sudo rm -f /etc/nginx/conf.d/pay.sasori.dev-le.conf 2>/dev/null
sudo rm -f /etc/nginx/conf.d/pay.sasori.dev.conf 2>/dev/null

# 4. HestiaCP 기본 도메인 비활성화 (있는 경우)
echo ""
echo "[4] HestiaCP 기본 설정 확인..."
if [ -f "/home/admin/conf/web/nginx.conf" ]; then
    echo "HestiaCP nginx 설정 발견"
    # server.domain.com 설정 비활성화
    sudo sed -i 's/server_name server.domain.com/server_name disabled.server.domain.com/g' /home/admin/conf/web/*.conf 2>/dev/null
fi

# 5. nginx 테스트
echo ""
echo "[5] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    # 6. nginx 재시작
    echo ""
    echo "[6] nginx 재시작..."
    sudo systemctl reload nginx

    # 7. 즉시 테스트
    echo ""
    echo "===== 테스트 결과 ====="
    echo ""

    echo "1️⃣ HTTPS 메인 페이지:"
    curl -k -s https://pay.sasori.dev | head -3
    echo ""

    echo "2️⃣ 테스트 엔드포인트:"
    curl -k -s https://pay.sasori.dev/test
    echo ""

    echo "3️⃣ Webhook 엔드포인트 (POST):"
    curl -k -s -X POST https://pay.sasori.dev/crypto-pay/webhook \
        -H "Content-Type: application/json" \
        -d '{"test":"message"}' \
        -w "\nHTTP Status: %{http_code}\n"
    echo ""

    echo "4️⃣ 커스텀 헤더 확인:"
    curl -k -I -s https://pay.sasori.dev | grep "X-Custom-Server"
    echo ""

    echo "✅ 설정이 완료되었습니다!"
    echo ""
    echo "📝 Cloudflare 설정:"
    echo "  1. Cloudflare 대시보드 → pay.sasori.dev"
    echo "  2. SSL/TLS → Overview"
    echo "  3. 'Full (strict)' 모드로 변경"

else
    echo ""
    echo "❌ nginx 설정 오류!"
    echo "현재 설정:"
    ls -la /etc/nginx/conf.d/*.conf
fi
#!/bin/bash
# 웹훅 프록시 설정 수정

echo "===== 웹훅 프록시 설정 수정 ====="
echo ""

# 1. 현재 nginx 설정 경로 찾기
echo "[1] nginx 설정 경로 확인..."
if [ -d "/etc/nginx/sites-available" ]; then
    CONFIG_DIR="/etc/nginx/sites-available"
    ENABLED_DIR="/etc/nginx/sites-enabled"
elif [ -d "/etc/nginx/conf.d" ]; then
    CONFIG_DIR="/etc/nginx/conf.d"
    ENABLED_DIR=""
else
    echo "❌ nginx 설정 디렉토리를 찾을 수 없습니다!"
    exit 1
fi

echo "설정 디렉토리: $CONFIG_DIR"

# 2. 웹훅 프록시 설정 생성
echo ""
echo "[2] 웹훅 프록시 설정 생성..."

cat > /tmp/pay-sasori-webhook.conf << 'EOF'
# Webhook Proxy Configuration
upstream webhook_backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name pay.sasori.dev;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name pay.sasori.dev;

    # SSL 인증서
    ssl_certificate /etc/letsencrypt/live/pay.sasori.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.sasori.dev/privkey.pem;

    # SSL 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 웹훅 엔드포인트
    location /crypto-pay/webhook {
        proxy_pass http://webhook_backend/crypto-pay/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 헬스체크
    location /health {
        proxy_pass http://webhook_backend/health;
    }

    # 메인 페이지
    location / {
        proxy_pass http://webhook_backend/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    # 로그
    access_log /var/log/nginx/pay-webhook-access.log;
    error_log /var/log/nginx/pay-webhook-error.log;
}
EOF

# 3. 설정 복사
echo ""
echo "[3] nginx 설정 적용..."
sudo cp /tmp/pay-sasori-webhook.conf $CONFIG_DIR/pay-sasori-webhook.conf

if [ ! -z "$ENABLED_DIR" ]; then
    sudo ln -sf $CONFIG_DIR/pay-sasori-webhook.conf $ENABLED_DIR/
fi

# 4. nginx 테스트
echo ""
echo "[4] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "[5] nginx 리로드..."
    sudo systemctl reload nginx

    echo ""
    echo "===== 테스트 ====="
    echo ""

    # 로컬 테스트
    echo "1️⃣ 로컬 서버 테스트:"
    curl -s http://127.0.0.1:8080/health | jq '.' 2>/dev/null || curl -s http://127.0.0.1:8080/health
    echo ""

    # HTTPS 테스트
    echo "2️⃣ HTTPS 헬스체크:"
    curl -k -s https://pay.sasori.dev/health | jq '.' 2>/dev/null || curl -k -s https://pay.sasori.dev/health
    echo ""

    # 웹훅 테스트
    echo "3️⃣ 웹훅 엔드포인트 테스트:"
    curl -k -X POST https://pay.sasori.dev/crypto-pay/webhook \
        -H "Content-Type: application/json" \
        -d '{"update_type": "test", "payload": {"test": true}}' \
        -s | jq '.' 2>/dev/null || echo "응답 확인"

    echo ""
    echo "✅ 웹훅 프록시 설정 완료!"
else
    echo "❌ nginx 설정 오류!"
fi
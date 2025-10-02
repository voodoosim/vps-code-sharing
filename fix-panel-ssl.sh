#!/bin/bash
# HestiaCP와 Let's Encrypt 인증서 통합

DOMAIN="pay.sasori.dev"

echo "===== HestiaCP SSL 설정 수정 ====="
echo ""

# 1. 현재 활성 설정 확인
echo "[1] 현재 nginx 설정 파일들:"
ls -la /etc/nginx/conf.d/*.conf | grep -E "pay|ssl"
echo ""

# 2. 중복 설정 제거
echo "[2] 중복 설정 정리..."
# 기존 설정 백업
sudo cp /etc/nginx/conf.d/pay.sasori.dev.conf /etc/nginx/conf.d/pay.sasori.dev.conf.bak2 2>/dev/null

# 이전 SSL 설정 제거
sudo rm -f /etc/nginx/conf.d/00-pay.sasori.dev-ssl.conf 2>/dev/null

# 3. HestiaCP 도메인 설정 확인
echo "[3] HestiaCP 도메인 설정 확인..."
if [ -d "/home/admin/conf/web" ]; then
    echo "패널 설정 디렉토리 존재"
    # HestiaCP가 관리하는 도메인 확인
    ls -la /home/admin/conf/web/ 2>/dev/null | grep -i ssl | head -5
fi
echo ""

# 4. 통합 설정 생성 (Let's Encrypt 인증서 사용)
echo "[4] 통합 nginx 설정 생성..."

sudo tee /etc/nginx/conf.d/$DOMAIN-le.conf > /dev/null << 'EOF'
# Let's Encrypt SSL 설정
server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;

    # Let's Encrypt 갱신
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    # HTTPS로 리다이렉트
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name pay.sasori.dev;

    # Let's Encrypt 인증서 사용
    ssl_certificate /etc/letsencrypt/live/pay.sasori.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.sasori.dev/privkey.pem;

    # SSL 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # 보안 헤더
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Webhook 프록시
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080/crypto-pay/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 루트 응답
    location / {
        return 200 "SSL Active - Webhook: https://pay.sasori.dev/crypto-pay/webhook\n";
        add_header Content-Type text/plain;
    }

    access_log /var/log/nginx/$DOMAIN-access.log;
    error_log /var/log/nginx/$DOMAIN-error.log;
}
EOF

# 5. 기존 충돌 설정 제거
echo ""
echo "[5] 충돌하는 설정 제거..."
# 기존 pay.sasori.dev.conf 제거 (중복)
sudo mv /etc/nginx/conf.d/pay.sasori.dev.conf /etc/nginx/conf.d/pay.sasori.dev.conf.disabled 2>/dev/null

# 6. 설정 테스트
echo ""
echo "[6] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "[7] nginx 재시작..."
    sudo systemctl reload nginx

    echo ""
    echo "===== 설정 완료! ====="
    echo ""
    echo "🔍 테스트 명령어:"
    echo ""
    echo "# HTTP 리다이렉트 테스트"
    echo "curl -I http://pay.sasori.dev"
    echo ""
    echo "# HTTPS 접속 테스트 (Let's Encrypt 인증서)"
    echo "curl https://pay.sasori.dev"
    echo ""
    echo "# Webhook 테스트"
    echo "curl -X POST https://pay.sasori.dev/crypto-pay/webhook -d '{}'"
    echo ""
else
    echo ""
    echo "❌ 설정 오류!"
    echo "현재 설정 파일 목록:"
    ls -la /etc/nginx/conf.d/*.conf
fi
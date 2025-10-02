#!/bin/bash
# nginx 변수 오류 수정

echo "===== nginx 변수 오류 수정 ====="
echo ""

# 1. 잘못된 설정 백업
echo "[1] 오류 설정 백업..."
sudo cp /etc/nginx/conf.d/pay.sasori.dev-le.conf /etc/nginx/conf.d/pay.sasori.dev-le.conf.error 2>/dev/null

# 2. 수정된 설정 생성 (변수 오류 수정)
echo "[2] 올바른 nginx 설정 생성..."

sudo tee /etc/nginx/conf.d/pay.sasori.dev-le.conf > /dev/null << 'EOF'
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

    access_log /var/log/nginx/pay.sasori.dev-access.log;
    error_log /var/log/nginx/pay.sasori.dev-error.log;
}
EOF

echo "설정 파일 수정 완료!"

# 3. 다른 충돌 파일 정리
echo ""
echo "[3] 충돌 파일 정리..."
# 이전 백업 파일들 제거
sudo rm -f /etc/nginx/conf.d/pay.sasori.dev.conf.disabled 2>/dev/null
sudo rm -f /etc/nginx/conf.d/pay.sasori.dev.conf.bak* 2>/dev/null
sudo rm -f /etc/nginx/conf.d/00-pay.sasori.dev-ssl.conf 2>/dev/null

# 4. 설정 테스트
echo ""
echo "[4] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "[5] nginx 재시작..."
    sudo systemctl reload nginx

    echo ""
    echo "===== 설정 성공! ====="
    echo ""

    # 즉시 테스트
    echo "🔍 즉시 테스트 중..."
    echo ""
    echo "1. HTTP 리다이렉트:"
    curl -I -s http://pay.sasori.dev | head -3
    echo ""
    echo "2. HTTPS 접속:"
    curl -k -s https://pay.sasori.dev
    echo ""
    echo "3. Webhook 엔드포인트:"
    curl -k -s -X POST https://pay.sasori.dev/crypto-pay/webhook -d '{"test":1}' -w "\nStatus: %{http_code}\n"
    echo ""
    echo "✅ nginx가 정상적으로 작동 중입니다!"
    echo ""
    echo "📝 다음 단계:"
    echo "  1. 브라우저에서 https://pay.sasori.dev 접속 테스트"
    echo "  2. Cloudflare를 'Full (strict)' 모드로 변경"
else
    echo ""
    echo "❌ 아직 오류가 있습니다."
    echo ""
    echo "활성 설정 파일:"
    ls -la /etc/nginx/conf.d/*.conf | grep -v disabled
    echo ""
    echo "nginx 에러 로그:"
    sudo tail -5 /var/log/nginx/error.log
fi
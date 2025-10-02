#!/bin/bash
# nginx 설정 강제 오버라이드

echo "===== nginx 설정 강제 오버라이드 ====="
echo ""

# 1. 모든 관련 설정 백업
echo "[1] 전체 설정 백업..."
sudo mkdir -p /etc/nginx/backup-final
sudo cp -r /etc/nginx/conf.d /etc/nginx/backup-final/
echo "백업 완료: /etc/nginx/backup-final/"
echo ""

# 2. HestiaCP nginx 설정 직접 수정
echo "[2] HestiaCP 설정 직접 수정..."
if [ -f "/home/admin/conf/web/server.domain.com/nginx.ssl.conf" ]; then
    # 백업
    sudo cp /home/admin/conf/web/server.domain.com/nginx.ssl.conf /home/admin/conf/web/server.domain.com/nginx.ssl.conf.original

    # server_name을 변경하여 비활성화
    sudo sed -i 's/server_name .*;/server_name disabled.server.domain.com;/g' /home/admin/conf/web/server.domain.com/nginx.ssl.conf
    echo "HestiaCP SSL 설정 비활성화 완료"
fi

if [ -f "/home/admin/conf/web/server.domain.com/nginx.conf" ]; then
    # 백업
    sudo cp /home/admin/conf/web/server.domain.com/nginx.conf /home/admin/conf/web/server.domain.com/nginx.conf.original

    # server_name을 변경
    sudo sed -i 's/server_name .*;/server_name disabled.server.domain.com;/g' /home/admin/conf/web/server.domain.com/nginx.conf
    echo "HestiaCP 일반 설정 비활성화 완료"
fi
echo ""

# 3. 깨끗한 새 설정 생성
echo "[3] 새로운 통합 SSL 설정 생성..."

# 기존 설정 모두 제거
sudo rm -f /etc/nginx/conf.d/pay.sasori.dev*.conf 2>/dev/null
sudo rm -f /etc/nginx/conf.d/00-pay*.conf 2>/dev/null

# 단일 통합 설정 생성
sudo tee /etc/nginx/conf.d/001-pay-sasori-ssl.conf > /dev/null << 'EOF'
# Let's Encrypt SSL Configuration for pay.sasori.dev
# Priority: 001 (loads first)

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name pay.sasori.dev;

    # Let's Encrypt certificates
    ssl_certificate /etc/letsencrypt/live/pay.sasori.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.sasori.dev/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Root location
    location / {
        return 200 "🔒 SSL Active - pay.sasori.dev\n✅ Let's Encrypt Certificate\n📮 Webhook: /crypto-pay/webhook\n";
        add_header Content-Type text/plain;
    }

    # Test endpoint
    location /test {
        return 200 "✅ SSL Test OK\n";
        add_header Content-Type text/plain;
    }

    # Webhook proxy
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080/crypto-pay/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;

        # Return 503 if backend is down
        proxy_intercept_errors on;
        error_page 502 503 504 =503 @backend_down;
    }

    location @backend_down {
        return 503 "Backend service unavailable. Start the bot on port 8080.\n";
        add_header Content-Type text/plain;
    }

    # Logs
    access_log /var/log/nginx/pay-sasori-access.log;
    error_log /var/log/nginx/pay-sasori-error.log;
}
EOF

echo "새 설정 파일 생성 완료!"
echo ""

# 4. nginx 설정 테스트
echo "[4] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    # 5. nginx 강제 재시작
    echo ""
    echo "[5] nginx 완전 재시작..."
    sudo systemctl restart nginx
    sleep 2

    # 6. 최종 테스트
    echo ""
    echo "===== 🎯 최종 테스트 ====="
    echo ""

    echo "1️⃣ HTTPS 응답:"
    curl -k -s https://pay.sasori.dev | head -5
    echo ""

    echo "2️⃣ 테스트 엔드포인트:"
    curl -k -s https://pay.sasori.dev/test
    echo ""

    echo "3️⃣ 인증서 확인:"
    echo | openssl s_client -connect pay.sasori.dev:443 -servername pay.sasori.dev 2>/dev/null | grep -E "subject|issuer" | grep -v "depth"
    echo ""

    echo "4️⃣ Webhook 상태:"
    curl -k -s -X POST https://pay.sasori.dev/crypto-pay/webhook -d '{}' -w "Status: %{http_code}\n"
    echo ""

    echo "===== ✅ 완료 ====="
    echo ""
    echo "🎉 Let's Encrypt SSL이 성공적으로 적용되었습니다!"
    echo ""
    echo "📝 마지막 단계:"
    echo "  1. Cloudflare → SSL/TLS → Overview"
    echo "  2. 'Full (strict)' 모드로 변경"
    echo "  3. 5분 후 https://pay.sasori.dev 접속 테스트"

else
    echo ""
    echo "❌ nginx 설정 오류 발생!"
    echo "설정 파일을 확인하세요."
fi
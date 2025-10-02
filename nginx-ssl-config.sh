#!/bin/bash
# nginx SSL 설정 스크립트

DOMAIN="pay.sasori.dev"
APP_PORT="8080"

echo "===== nginx SSL 설정 ====="
echo ""

# 1. 기존 설정 백업
echo "[1] 기존 nginx 설정 백업..."
if [ -f "/etc/nginx/conf.d/$DOMAIN.conf" ]; then
    sudo cp /etc/nginx/conf.d/$DOMAIN.conf /etc/nginx/conf.d/$DOMAIN.conf.backup
    echo "백업 완료: /etc/nginx/conf.d/$DOMAIN.conf.backup"
fi

# 2. SSL 설정 생성
echo ""
echo "[2] SSL nginx 설정 생성..."

sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << EOF
# HTTP to HTTPS 리다이렉트
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Let's Encrypt 갱신용 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    # 나머지는 HTTPS로 리다이렉트
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS 서버 설정
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL 인증서 경로
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL 보안 설정
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # 모던 SSL 프로토콜
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # HSTS 헤더
    add_header Strict-Transport-Security "max-age=63072000" always;

    # Webhook 엔드포인트 프록시
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:$APP_PORT/crypto-pay/webhook;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # 버퍼 설정
        proxy_buffering off;
        proxy_request_buffering off;

        # 로깅
        access_log /var/log/nginx/webhook-access.log;
        error_log /var/log/nginx/webhook-error.log;
    }

    # 기본 응답
    location / {
        return 200 "SSL Enabled - Webhook endpoint: https://$DOMAIN/crypto-pay/webhook\n";
        add_header Content-Type text/plain;
    }

    # 보안 헤더
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 로그 파일
    access_log /var/log/nginx/$DOMAIN-ssl-access.log;
    error_log /var/log/nginx/$DOMAIN-ssl-error.log;
}
EOF

echo "SSL nginx 설정 생성 완료!"

# 3. nginx 설정 테스트
echo ""
echo "[3] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "[4] nginx 재시작..."
    sudo systemctl reload nginx

    echo ""
    echo "===== 설정 완료! ====="
    echo ""
    echo "📋 설정 정보:"
    echo "  - HTTPS URL: https://$DOMAIN"
    echo "  - Webhook URL: https://$DOMAIN/crypto-pay/webhook"
    echo "  - 인증서 경로: /etc/letsencrypt/live/$DOMAIN/"
    echo "  - 인증서 만료: 2025-12-31"
    echo ""
    echo "🔄 다음 단계:"
    echo "  1. HTTPS 접속 테스트: curl https://$DOMAIN"
    echo "  2. Webhook 테스트: curl -X POST https://$DOMAIN/crypto-pay/webhook"
    echo "  3. Cloudflare를 'Full (strict)' 모드로 변경"
    echo ""
    echo "✅ SSL 설정이 성공적으로 완료되었습니다!"
else
    echo ""
    echo "❌ nginx 설정 오류 발생!"
    echo "설정 파일을 확인하세요: /etc/nginx/conf.d/$DOMAIN.conf"
    echo ""
    echo "문제 해결:"
    echo "1. 설정 파일 구문 확인: sudo nginx -t"
    echo "2. 인증서 파일 확인:"
    echo "   ls -la /etc/letsencrypt/live/$DOMAIN/"
    echo "3. nginx 로그 확인:"
    echo "   sudo tail -f /var/log/nginx/error.log"
fi
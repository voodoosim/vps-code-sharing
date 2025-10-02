#!/bin/bash
# nginx 설정 충돌 해결 스크립트

DOMAIN="pay.sasori.dev"
APP_PORT="8080"

echo "===== nginx 설정 충돌 해결 ====="
echo ""

# 1. 기존 설정 확인
echo "[1] 기존 nginx 설정 파일 확인..."
echo "현재 설정 파일들:"
ls -la /etc/nginx/conf.d/
echo ""

# 2. 충돌하는 SSL 설정 찾기
echo "[2] SSL 메모리 존 충돌 확인..."
echo "SSL 메모리 존 선언 찾기:"
sudo grep -r "ssl_session_cache" /etc/nginx/ 2>/dev/null || echo "검색 권한 필요"
echo ""

# 3. 수정된 설정 생성 (충돌 해결)
echo "[3] 수정된 nginx 설정 생성..."

sudo tee /etc/nginx/conf.d/$DOMAIN.conf > /dev/null << 'EOF'
# HTTP to HTTPS 리다이렉트
server {
    listen 80;
    listen [::]:80;
    server_name pay.sasori.dev;

    # Let's Encrypt 갱신용 경로
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    # 나머지는 HTTPS로 리다이렉트
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS 서버 설정
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name pay.sasori.dev;

    # SSL 인증서 경로
    ssl_certificate /etc/letsencrypt/live/pay.sasori.dev/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.sasori.dev/privkey.pem;

    # SSL 보안 설정 (SSL 캐시는 주석 처리 - 다른 곳에서 이미 선언됨)
    ssl_session_timeout 1d;
    # ssl_session_cache shared:SSL:10m;  # 충돌 방지를 위해 주석 처리
    ssl_session_tickets off;

    # 모던 SSL 프로토콜
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # HSTS 헤더
    add_header Strict-Transport-Security "max-age=63072000" always;

    # Webhook 엔드포인트 프록시
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080/crypto-pay/webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
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
        return 200 "SSL Enabled - Webhook endpoint: https://pay.sasori.dev/crypto-pay/webhook\n";
        add_header Content-Type text/plain;
    }

    # 보안 헤더
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 로그 파일
    access_log /var/log/nginx/pay.sasori.dev-ssl-access.log;
    error_log /var/log/nginx/pay.sasori.dev-ssl-error.log;
}
EOF

echo "설정 파일 생성 완료!"

# 4. 인증서 파일 확인
echo ""
echo "[4] SSL 인증서 파일 확인..."
sudo ls -la /etc/letsencrypt/live/$DOMAIN/ 2>/dev/null || echo "인증서 디렉토리 접근 권한 필요"

# 5. nginx 설정 테스트
echo ""
echo "[5] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "[6] nginx 재시작..."
    sudo systemctl reload nginx

    echo ""
    echo "===== 설정 성공! ====="
    echo ""
    echo "✅ nginx가 성공적으로 재시작되었습니다!"
    echo ""
    echo "테스트 명령어:"
    echo "  curl https://$DOMAIN"
    echo "  curl -X POST https://$DOMAIN/crypto-pay/webhook"
else
    echo ""
    echo "❌ 아직 설정 오류가 있습니다."
    echo ""
    echo "추가 확인 사항:"
    echo "1. 다른 설정 파일에서 SSL 캐시 선언 확인:"
    echo "   sudo grep -r 'ssl_session_cache' /etc/nginx/"
    echo ""
    echo "2. HestiaCP/VestaCP 설정 확인:"
    echo "   ls -la /home/admin/conf/web/"
    echo ""
    echo "3. 기본 nginx 설정 확인:"
    echo "   cat /etc/nginx/nginx.conf | grep ssl"
fi
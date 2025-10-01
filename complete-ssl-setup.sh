#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"
APP_PORT="${APP_PORT:-8080}"

echo "🔐 완전한 SSL 설정 스크립트"
echo "================================"
echo "도메인: ${DOMAIN}"
echo "앱 포트: ${APP_PORT}"
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 기본 패키지 설치
echo -e "${YELLOW}[1/10] 필수 패키지 설치${NC}"
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx curl dig

# 2. DNS 확인
echo -e "${YELLOW}[2/10] DNS 설정 확인${NC}"
DOMAIN_IP=$(dig +short ${DOMAIN} | head -1)
SERVER_IP=$(curl -s ifconfig.me)
echo "도메인 IP: ${DOMAIN_IP}"
echo "서버 IP: ${SERVER_IP}"

if [ "${DOMAIN_IP}" != "${SERVER_IP}" ]; then
    echo -e "${RED}⚠️  경고: 도메인이 서버 IP를 가리키지 않습니다!${NC}"
    echo "Cloudflare를 사용중이라면 DNS only 모드(회색 구름)로 설정하세요."
fi

# 3. 기존 nginx 설정 정리
echo -e "${YELLOW}[3/10] 기존 nginx 설정 정리${NC}"
# 충돌하는 설정 백업
for conf in /etc/nginx/sites-enabled/default /etc/nginx/conf.d/pay.conf /etc/nginx/sites-available/${DOMAIN}; do
    if [ -f "$conf" ]; then
        sudo mv "$conf" "${conf}.bak-$(date +%Y%m%d)" 2>/dev/null || true
        echo "백업됨: ${conf}"
    fi
done

# 심볼릭 링크 제거
if [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi
if [ -L /etc/nginx/sites-enabled/${DOMAIN} ]; then
    sudo rm /etc/nginx/sites-enabled/${DOMAIN}
fi

# 4. 웹루트 디렉토리 생성
echo -e "${YELLOW}[4/10] 웹루트 디렉토리 설정${NC}"
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# 테스트 파일 생성
echo "acme-test-$(date +%s)" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt > /dev/null

# 5. HTTP용 nginx 설정 생성
echo -e "${YELLOW}[5/10] HTTP nginx 설정 생성${NC}"
sudo tee /etc/nginx/sites-available/${DOMAIN}-http > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root /var/www/html;
    index index.html index.htm;

    # ACME 챌린지를 위한 설정
    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
        try_files \$uri =404;
    }

    # 기본 위치
    location / {
        try_files \$uri \$uri/ =404;
    }

    # 디버깅용 로그
    access_log /var/log/nginx/${DOMAIN}-access.log;
    error_log /var/log/nginx/${DOMAIN}-error.log debug;
}
EOF

# 6. nginx 설정 활성화
echo -e "${YELLOW}[6/10] nginx 설정 활성화${NC}"
sudo ln -sf /etc/nginx/sites-available/${DOMAIN}-http /etc/nginx/sites-enabled/

# nginx 설정 테스트
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx 설정 유효${NC}"
    sudo systemctl reload nginx
else
    echo -e "${RED}❌ nginx 설정 오류!${NC}"
    exit 1
fi

# 7. HTTP 접근 테스트
echo -e "${YELLOW}[7/10] HTTP 접근 테스트${NC}"
sleep 2
HTTP_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://${DOMAIN}/.well-known/acme-challenge/test.txt || echo "000")
if [ "$HTTP_TEST" = "200" ]; then
    echo -e "${GREEN}✅ HTTP 접근 성공${NC}"
else
    echo -e "${RED}❌ HTTP 접근 실패 (코드: $HTTP_TEST)${NC}"
    echo "nginx 로그 확인:"
    sudo tail -n 20 /var/log/nginx/${DOMAIN}-error.log
fi

# 8. 방화벽 설정
echo -e "${YELLOW}[8/10] 방화벽 포트 확인${NC}"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 'Nginx Full'
    echo -e "${GREEN}✅ 방화벽 포트 열림${NC}"
fi

# 9. SSL 인증서 발급
echo -e "${YELLOW}[9/10] SSL 인증서 발급 시도${NC}"
echo -e "${YELLOW}📌 중요: Cloudflare를 사용중이라면 반드시 DNS only 모드(회색 구름)로 설정하세요!${NC}"
echo ""

# webroot 방식으로 인증서 발급 시도
if sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}; then
    echo -e "${GREEN}✅ SSL 인증서 발급 성공!${NC}"

    # 10. HTTPS 설정 추가
    echo -e "${YELLOW}[10/10] HTTPS 설정 적용${NC}"

    sudo tee /etc/nginx/sites-available/${DOMAIN} > /dev/null <<EOF
# HTTP to HTTPS 리다이렉트
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTPS 서버
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # SSL 설정
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256";

    # 보안 헤더
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

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

        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

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
        default_type text/html;
        return 200 '<!DOCTYPE html>
<html>
<head>
    <title>${DOMAIN}</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .status { color: green; font-weight: bold; }
        .endpoint { background: #f0f0f0; padding: 15px; border-radius: 5px; margin: 15px 0; }
        code { background: #333; color: #fff; padding: 3px 8px; border-radius: 3px; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🔐 ${DOMAIN}</h1>
    <p class="status">✅ SSL 인증서 활성</p>

    <div class="endpoint">
        <h3>📍 Webhook Endpoint</h3>
        <p>URL: <code>https://${DOMAIN}/crypto-pay/webhook</code></p>
        <p>프록시 대상: <code>127.0.0.1:${APP_PORT}</code></p>
    </div>

    <div class="endpoint">
        <h3>🧪 테스트 명령</h3>
        <pre>curl -X POST https://${DOMAIN}/crypto-pay/webhook \\
  -H "Content-Type: application/json" \\
  -d "{\"test\": true}"</pre>
    </div>

    <div class="endpoint">
        <h3>📊 상태 확인</h3>
        <p>헬스체크: <code>GET https://${DOMAIN}/health</code></p>
    </div>
</body>
</html>';
    }

    # 로그 파일
    access_log /var/log/nginx/${DOMAIN}-access.log;
    error_log /var/log/nginx/${DOMAIN}-error.log;
}
EOF

    # 기존 HTTP 설정 제거
    sudo rm /etc/nginx/sites-enabled/${DOMAIN}-http

    # HTTPS 설정 활성화
    sudo ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

    # nginx 재시작
    sudo nginx -t && sudo systemctl reload nginx

    echo ""
    echo -e "${GREEN}🎉 설정 완료!${NC}"
    echo "================================"
    echo "✅ SSL 인증서: 활성"
    echo "✅ HTTPS: https://${DOMAIN}/"
    echo "✅ Webhook: https://${DOMAIN}/crypto-pay/webhook"
    echo "✅ 프록시: 127.0.0.1:${APP_PORT}"
    echo ""
    echo "📝 테스트 명령어:"
    echo "curl -i https://${DOMAIN}/"
    echo "curl -i https://${DOMAIN}/health"
    echo "curl -X POST https://${DOMAIN}/crypto-pay/webhook -H 'Content-Type: application/json' -d '{\"test\":true}'"

else
    echo -e "${RED}❌ SSL 인증서 발급 실패!${NC}"
    echo ""
    echo "문제 해결 방법:"
    echo "1. Cloudflare DNS only 모드 확인 (회색 구름)"
    echo "2. 도메인 DNS A 레코드 확인"
    echo "3. 방화벽 포트 80, 443 열림 확인"
    echo ""
    echo "수동 테스트:"
    echo "curl -v http://${DOMAIN}/.well-known/acme-challenge/test.txt"
    echo ""
    echo "nginx 로그 확인:"
    echo "sudo tail -f /var/log/nginx/${DOMAIN}-error.log"
    echo ""
    echo "다시 시도하려면:"
    echo "sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN}"
fi
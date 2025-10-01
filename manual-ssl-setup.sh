#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"
APP_PORT="${APP_PORT:-8080}"

echo "🔐 수동 SSL 설정 스크립트"
echo "================================"

echo "[1/3] 현재 nginx 설정 확인"
if [ -f /etc/nginx/conf.d/pay.conf ]; then
    echo "✅ 기존 설정 발견: /etc/nginx/conf.d/pay.conf"
    sudo cat /etc/nginx/conf.d/pay.conf
    echo ""
fi

echo "[2/3] Certbot 실행 (인터랙티브 모드)"
echo "⚠️  다음 프롬프트에 답변해주세요:"
echo "  - 이메일 주소 입력 (알림용)"
echo "  - 약관 동의 (A)"
echo "  - 뉴스레터 (N 추천)"
echo ""

# 인터랙티브 모드로 실행
sudo certbot --nginx -d "${DOMAIN}" --redirect

echo ""
echo "[3/3] SSL 발급 결과 확인"
if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "✅ SSL 인증서 발급 성공!"

    # Webhook 프록시 설정 추가
    echo ""
    echo "Webhook 프록시 설정 업데이트 중..."

    # 현재 nginx 설정 백업
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak 2>/dev/null || true

    # pay.conf 파일 업데이트 (443 서버 블록에 webhook location 추가)
    sudo tee /etc/nginx/conf.d/pay-webhook.conf > /dev/null <<EOF
# Webhook 프록시 설정
# 이 파일은 별도로 관리됩니다
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Webhook 엔드포인트
    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 30s;
        proxy_connect_timeout 10s;

        # 로깅 (디버깅용)
        access_log /var/log/nginx/webhook-access.log;
        error_log /var/log/nginx/webhook-error.log;
    }

    # 헬스체크 엔드포인트
    location /health {
        access_log off;
        default_type text/plain;
        return 200 "OK";
    }

    # 기본 페이지
    location / {
        default_type text/html;
        return 200 '<html>
<head><title>${DOMAIN}</title></head>
<body>
<h1>✅ SSL Enabled</h1>
<p>Webhook endpoint: <code>/crypto-pay/webhook</code></p>
<p>Port: <code>${APP_PORT}</code></p>
<p>Status: <span style="color:green">Active</span></p>
</body>
</html>';
        add_header Content-Type text/html;
    }
}

# HTTP to HTTPS 리다이렉트
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOF

    # nginx 설정 테스트
    sudo nginx -t && sudo systemctl reload nginx

    echo ""
    echo "🎉 설정 완료!"
    echo "================================"
    echo "✅ SSL 인증서: 활성"
    echo "✅ HTTPS 리다이렉트: 활성"
    echo "✅ Webhook 엔드포인트: https://${DOMAIN}/crypto-pay/webhook"
    echo "✅ 프록시 타겟: 127.0.0.1:${APP_PORT}"
    echo ""
    echo "📝 테스트 명령어:"
    echo ""
    echo "# HTTPS 연결 테스트"
    echo "curl -i https://${DOMAIN}/"
    echo ""
    echo "# Webhook 테스트 (앱이 실행중이 아니면 502 오류)"
    echo "curl -i -X POST https://${DOMAIN}/crypto-pay/webhook \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"ping\":true}'"
    echo ""
    echo "# 로그 확인"
    echo "sudo tail -f /var/log/nginx/webhook-access.log"
    echo "sudo tail -f /var/log/nginx/webhook-error.log"

else
    echo "❌ SSL 인증서 발급 실패!"
    echo ""
    echo "문제 해결:"
    echo "1. Cloudflare DNS only 모드 확인"
    echo "2. 도메인이 서버 IP를 가리키는지 확인:"
    echo "   dig ${DOMAIN} +short"
    echo "3. 방화벽 포트 80, 443 열려있는지 확인:"
    echo "   sudo ufw status"
fi
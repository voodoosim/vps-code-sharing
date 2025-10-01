#!/usr/bin/env bash
set -euo pipefail
DOMAIN="${DOMAIN:-pay.sasori.dev}"

echo "🔍 Nginx 및 도메인 디버깅 스크립트"
echo "================================"

echo "[1] 도메인 DNS 확인"
echo -n "도메인 IP: "
dig ${DOMAIN} +short
echo -n "서버 IP: "
curl -s ifconfig.me
echo ""

echo "[2] Nginx 설정 파일 확인"
echo "Sites-enabled:"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "디렉토리 없음"
echo ""
echo "Sites-available:"
ls -la /etc/nginx/sites-available/ 2>/dev/null || echo "디렉토리 없음"
echo ""
echo "Conf.d:"
ls -la /etc/nginx/conf.d/ 2>/dev/null || echo "디렉토리 없음"
echo ""

echo "[3] 현재 nginx 설정 내용"
if [ -f /etc/nginx/conf.d/pay.conf ]; then
    echo "=== /etc/nginx/conf.d/pay.conf ==="
    sudo cat /etc/nginx/conf.d/pay.conf
fi

if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "=== /etc/nginx/sites-enabled/default (일부) ==="
    sudo head -50 /etc/nginx/sites-enabled/default
fi

echo ""
echo "[4] Nginx 프로세스 확인"
sudo nginx -t
ps aux | grep nginx | head -5

echo ""
echo "[5] 포트 리스닝 확인"
sudo netstat -tlnp | grep -E ':80|:443' || sudo ss -tlnp | grep -E ':80|:443'

echo ""
echo "[6] 수정된 Nginx 설정 생성"
echo "새로운 설정을 /etc/nginx/sites-available/${DOMAIN} 에 생성합니다..."

# 기존 설정 백업
if [ -f /etc/nginx/sites-enabled/default ]; then
    sudo cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak
fi

# 새 설정 생성
sudo tee /etc/nginx/sites-available/${DOMAIN} > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    # Let's Encrypt 인증용
    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# 심볼릭 링크 생성
sudo ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# 기본 default 사이트 비활성화 (충돌 방지)
if [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi

# conf.d의 pay.conf도 임시로 비활성화
if [ -f /etc/nginx/conf.d/pay.conf ]; then
    sudo mv /etc/nginx/conf.d/pay.conf /etc/nginx/conf.d/pay.conf.disabled
fi

echo ""
echo "[7] Nginx 재시작"
sudo nginx -t && sudo systemctl reload nginx

echo ""
echo "[8] 테스트 디렉토리 생성"
sudo mkdir -p /var/www/html/.well-known/acme-challenge/
echo "test-file" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt

echo ""
echo "[9] 테스트"
echo "HTTP 테스트:"
curl -I http://${DOMAIN}/.well-known/acme-challenge/test.txt

echo ""
echo "✅ 준비 완료! 이제 Certbot을 다시 실행하세요:"
echo ""
echo "sudo certbot --nginx -d ${DOMAIN} --redirect"
echo ""
echo "또는 webroot 방식으로:"
echo "sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN}"
echo ""
echo "인증서 발급 후 webhook 설정을 추가하려면:"
echo "curl -fsSL https://raw.githubusercontent.com/voodoosim/vps-code-sharing/main/add-webhook-config.sh | sudo bash"
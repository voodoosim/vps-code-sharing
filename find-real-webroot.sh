#!/bin/bash
# 실제 웹루트 찾기 스크립트

DOMAIN="pay.sasori.dev"

echo "===== Finding Real Webroot ====="
echo ""

# 1. 가능한 웹루트 위치들 확인
echo "[1] Checking possible webroot locations..."
POSSIBLE_PATHS=(
    "/home/admin/web/$DOMAIN/public_html"
    "/home/admin/web/$DOMAIN/public_shtml" 
    "/home/developer/web/$DOMAIN/public_html"
    "/var/www/$DOMAIN"
    "/var/www/html"
    "/usr/share/nginx/html"
    "/home/admin/domains/$DOMAIN/public_html"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "✅ Found: $path"
        WEBROOT="$path"
    else
        echo "❌ Not found: $path"
    fi
done

# 2. admin 홈 디렉토리 확인
echo ""
echo "[2] Checking /home/admin structure..."
if [ -d "/home/admin/web" ]; then
    echo "Domains in /home/admin/web:"
    ls -la /home/admin/web/
fi

# 3. nginx 설정에서 root 찾기
echo ""
echo "[3] Searching nginx configs for document root..."
echo ""
echo "Main nginx config:"
grep -r "root\|server_name pay.sasori.dev" /etc/nginx/conf.d/ 2>/dev/null | grep -B2 -A2 "pay.sasori.dev"

# 4. 패널 설정 확인
echo ""
echo "[4] Checking panel configs..."
if [ -d "/home/admin/conf/web" ]; then
    echo "Panel nginx configs:"
    ls -la /home/admin/conf/web/
    
    if [ -f "/home/admin/conf/web/pay.sasori.dev/nginx.conf" ]; then
        echo ""
        echo "Found panel config for domain:"
        grep "root" /home/admin/conf/web/pay.sasori.dev/nginx.conf
    fi
fi

# 5. 테스트 파일 생성
echo ""
echo "[5] Creating test files in found locations..."
if [ ! -z "$WEBROOT" ]; then
    echo "Using webroot: $WEBROOT"
    sudo mkdir -p "$WEBROOT/.well-known/acme-challenge"
    echo "webroot-test-$$" | sudo tee "$WEBROOT/.well-known/acme-challenge/test.txt"
    sudo chown -R admin:admin "$WEBROOT/.well-known" 2>/dev/null || sudo chown -R www-data:www-data "$WEBROOT/.well-known"
    
    echo ""
    echo "Testing access:"
    curl -s "http://$DOMAIN/.well-known/acme-challenge/test.txt"
    
    echo ""
    echo "[6] If you see 'webroot-test-' above, use this command:"
    echo "sudo certbot certonly --webroot -w $WEBROOT -d $DOMAIN --agree-tos --email voodoosim44@proton.me"
else
    echo "No webroot found. Manual investigation needed."
fi
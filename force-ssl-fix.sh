#!/bin/bash
# 강제 SSL 설정 스크립트

DOMAIN="pay.sasori.dev"

echo "===== Force SSL Fix ====="
echo ""

# 1. 패널의 도메인 디렉토리 찾기
echo "[1] Finding domain directory..."
if [ -d "/home/admin/web/$DOMAIN/public_html" ]; then
    WEBROOT="/home/admin/web/$DOMAIN/public_html"
    echo "Found panel webroot: $WEBROOT"
elif [ -d "/home/developer/web/$DOMAIN/public_html" ]; then
    WEBROOT="/home/developer/web/$DOMAIN/public_html"
    echo "Found webroot: $WEBROOT"
else
    WEBROOT="/var/www/html"
    echo "Using default: $WEBROOT"
fi

# 2. ACME 디렉토리 생성 (패널 웹루트에)
echo ""
echo "[2] Creating ACME directory in webroot..."
sudo mkdir -p $WEBROOT/.well-known/acme-challenge
sudo chmod 755 $WEBROOT/.well-known
sudo chmod 755 $WEBROOT/.well-known/acme-challenge

# 3. 테스트 파일 생성
echo ""
echo "[3] Creating test file..."
echo "ssl-test-working" | sudo tee $WEBROOT/.well-known/acme-challenge/test.txt

# 4. 권한 설정
echo ""
echo "[4] Setting permissions..."
if [ -d "/home/admin/web" ]; then
    sudo chown -R admin:admin $WEBROOT/.well-known
elif [ -d "/home/developer/web" ]; then
    sudo chown -R developer:developer $WEBROOT/.well-known
else
    sudo chown -R www-data:www-data $WEBROOT/.well-known
fi

# 5. 테스트
echo ""
echo "[5] Testing access..."
echo "Webroot contents:"
ls -la $WEBROOT/.well-known/acme-challenge/

echo ""
echo "Testing via curl:"
curl -s http://$DOMAIN/.well-known/acme-challenge/test.txt
RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "If you see 'ssl-test-working' above, run:"
    echo ""
    echo "sudo certbot certonly --webroot -w $WEBROOT -d $DOMAIN --agree-tos --email voodoosim44@proton.me"
else
    echo ""
    echo "Still not working. Checking nginx includes..."
    
    # 6. nginx include 파일 확인
    echo ""
    echo "[6] Checking nginx includes..."
    grep -r "include" /etc/nginx/nginx.conf
    
    echo ""
    echo "[7] Creating override in main nginx config..."
    
    # 직접 nginx.conf에 추가
    sudo tee /etc/nginx/conf.d/00-priority-ssl.conf << EOF
# Priority SSL configuration
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root $WEBROOT;
        allow all;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF
    
    # nginx 재시작
    sudo nginx -t && sudo systemctl reload nginx
    
    echo ""
    echo "Testing again:"
    curl -s http://$DOMAIN/.well-known/acme-challenge/test.txt
fi
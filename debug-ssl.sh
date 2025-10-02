#!/bin/bash
# SSL 문제 디버깅 스크립트

DOMAIN="pay.sasori.dev"

echo "===== SSL Debug Script ====="
echo ""

# 1. nginx 상태 확인
echo "[1] Nginx Status:"
sudo systemctl status nginx --no-pager | head -10

# 2. nginx 설정 파일 확인
echo ""
echo "[2] Nginx configs in /etc/nginx/conf.d/:"
ls -la /etc/nginx/conf.d/

echo ""
echo "[3] Current nginx config for $DOMAIN:"
cat /etc/nginx/conf.d/$DOMAIN.conf 2>/dev/null || echo "No config found"

# 4. Webroot 디렉토리 확인
echo ""
echo "[4] Webroot directories:"
echo "Checking /var/www/certbot:"
ls -la /var/www/certbot/ 2>/dev/null || echo "Directory not found"
ls -la /var/www/certbot/.well-known/acme-challenge/ 2>/dev/null || echo "ACME directory not found"

echo ""
echo "Checking /var/www/html:"
ls -la /var/www/html/.well-known/acme-challenge/ 2>/dev/null || echo "ACME directory not found"

# 5. 테스트 파일 생성 및 접근 테스트
echo ""
echo "[5] Creating test file in both locations:"
echo "test123" | sudo tee /var/www/certbot/.well-known/acme-challenge/test.txt > /dev/null
echo "test456" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt > /dev/null

# 6. 로컬 테스트
echo ""
echo "[6] Local access test:"
echo "Testing /var/www/certbot path:"
curl -s http://localhost/.well-known/acme-challenge/test.txt || echo "Failed"

echo ""
echo "Testing with domain:"
curl -s http://$DOMAIN/.well-known/acme-challenge/test.txt || echo "Failed"

# 7. nginx 로그 확인
echo ""
echo "[7] Recent nginx error logs:"
sudo tail -5 /var/log/nginx/error.log

echo ""
echo "[8] Recent nginx access logs:"
sudo tail -5 /var/log/nginx/access.log

# 8. DNS 확인
echo ""
echo "[9] DNS Resolution:"
dig +short $DOMAIN
echo "Current server IP:"
curl -s ifconfig.me

# 9. 포트 확인
echo ""
echo "[10] Port 80 listening:"
sudo netstat -tlnp | grep :80

echo ""
echo "===== Diagnosis Complete ====="
echo ""
echo "Common issues:"
echo "1. Cloudflare is proxying (should be DNS-only)"
echo "2. Wrong webroot path in nginx config"
echo "3. Firewall blocking port 80"
echo "4. DNS not pointing to this server"
#!/bin/bash
# HTTPS 테스트 스크립트

DOMAIN="pay.sasori.dev"

echo "===== HTTPS 테스트 ====="
echo ""

# 1. HTTP 리다이렉트 테스트
echo "[1] HTTP → HTTPS 리다이렉트 테스트..."
echo "Testing: http://$DOMAIN"
curl -I http://$DOMAIN 2>/dev/null | head -5
echo ""

# 2. HTTPS 접속 테스트
echo "[2] HTTPS 접속 테스트..."
echo "Testing: https://$DOMAIN"
curl -s https://$DOMAIN
echo ""

# 3. SSL 인증서 정보
echo "[3] SSL 인증서 정보..."
echo | openssl s_client -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates
echo ""

# 4. Webhook 엔드포인트 테스트
echo "[4] Webhook 엔드포인트 테스트..."
echo "Testing: POST https://$DOMAIN/crypto-pay/webhook"
curl -X POST https://$DOMAIN/crypto-pay/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "message"}' \
  -w "\nHTTP Status: %{http_code}\n"
echo ""

# 5. SSL 보안 등급 체크
echo "[5] SSL 보안 헤더 확인..."
curl -I https://$DOMAIN 2>/dev/null | grep -E "(Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options)"
echo ""

echo "===== 테스트 완료 ====="
echo ""
echo "✅ 체크리스트:"
echo "  [ ] HTTP가 HTTPS로 리다이렉트되는가?"
echo "  [ ] HTTPS 접속이 정상적인가?"
echo "  [ ] SSL 인증서가 유효한가?"
echo "  [ ] Webhook 엔드포인트가 접근 가능한가?"
echo "  [ ] 보안 헤더가 설정되어 있는가?"
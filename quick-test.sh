#!/bin/bash
# 빠른 SSL 테스트

echo "===== SSL 적용 확인 ====="
echo ""

echo "1. HTTPS 메인 페이지:"
curl -k -s https://pay.sasori.dev | head -5
echo ""

echo "2. 테스트 엔드포인트:"
curl -k -s https://pay.sasori.dev/test
echo ""

echo "3. Webhook 엔드포인트:"
curl -k -s -X POST https://pay.sasori.dev/crypto-pay/webhook \
    -H "Content-Type: application/json" \
    -d '{"test":"data"}' \
    -w "\nStatus: %{http_code}\n"
echo ""

echo "4. 헤더 확인:"
curl -k -I -s https://pay.sasori.dev | grep -E "Server:|X-Custom-Server:"
echo ""

echo "5. 인증서 확인:"
echo | openssl s_client -connect pay.sasori.dev:443 -servername pay.sasori.dev 2>/dev/null | grep -A2 "subject="
echo ""

echo "===== 테스트 완료 ====="
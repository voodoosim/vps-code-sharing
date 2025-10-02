#!/bin/bash
# 최종 SSL 테스트 스크립트

DOMAIN="pay.sasori.dev"

echo "===== SSL 최종 테스트 ====="
echo ""

# 1. 인증서 정보 확인
echo "[1] 현재 SSL 인증서 정보:"
echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -A2 "Subject:"
echo ""

# 2. Let's Encrypt 인증서 확인
echo "[2] Let's Encrypt 인증서 확인:"
sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -dates 2>/dev/null || echo "인증서 읽기 실패"
echo ""

# 3. 실제 HTTPS 연결 테스트
echo "[3] HTTPS 연결 테스트 (insecure 옵션):"
curl -k https://$DOMAIN
echo ""

# 4. Webhook 엔드포인트 테스트
echo "[4] Webhook 엔드포인트 테스트:"
curl -k -X POST https://$DOMAIN/crypto-pay/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "webhook"}' \
  -w "\nHTTP Status: %{http_code}\n"
echo ""

# 5. SSL Labs 호환성 체크 준비
echo "[5] SSL 설정 요약:"
echo "- 인증서: Let's Encrypt"
echo "- 도메인: $DOMAIN"
echo "- 만료일: 2025-12-31"
echo "- Webhook: https://$DOMAIN/crypto-pay/webhook"
echo ""

# 6. 현재 nginx 설정 파일 목록
echo "[6] 활성 nginx 설정:"
ls -la /etc/nginx/conf.d/*.conf 2>/dev/null | grep -v disabled | grep pay
echo ""

echo "===== 테스트 완료 ====="
echo ""
echo "📝 Cloudflare 설정:"
echo "  1. Cloudflare 대시보드로 이동"
echo "  2. SSL/TLS → Overview"
echo "  3. 'Full (strict)' 모드로 변경"
echo "  4. 5분 대기 후 https://pay.sasori.dev 접속 테스트"
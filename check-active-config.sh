#!/bin/bash
# 실제 적용된 nginx 설정 확인

echo "===== 실제 적용된 nginx 설정 확인 ====="
echo ""

# 1. 현재 활성 설정 파일들
echo "[1] 현재 nginx 설정 파일들:"
ls -la /etc/nginx/conf.d/*.conf | grep -E "pay|sasori"
echo ""

# 2. pay.sasori.dev에 대한 설정 확인
echo "[2] pay.sasori.dev 도메인 설정 찾기:"
sudo grep -r "server_name.*pay.sasori.dev" /etc/nginx/ 2>/dev/null | grep -v ".bak" | grep -v ".disabled"
echo ""

# 3. HestiaCP 도메인 설정 확인
echo "[3] HestiaCP 도메인 설정:"
if [ -d "/home/admin/conf/web" ]; then
    echo "패널 도메인 설정 검색:"
    sudo find /home/admin/conf/web -name "*.conf" 2>/dev/null | head -10

    # pay.sasori.dev 관련 설정 찾기
    echo ""
    echo "pay.sasori.dev 관련 HestiaCP 설정:"
    sudo grep -r "pay.sasori.dev" /home/admin/conf/web 2>/dev/null | head -5
fi
echo ""

# 4. 실제 HTTPS 응답 서버 확인
echo "[4] 실제 HTTPS 응답 확인:"
curl -k -I https://pay.sasori.dev 2>/dev/null | grep -E "Server:|X-"
echo ""

# 5. nginx include 확인
echo "[5] nginx.conf include 설정:"
sudo grep -E "include" /etc/nginx/nginx.conf | grep -v "#"
echo ""

# 6. 우선순위 문제 확인
echo "[6] server.domain.com 기본 설정 확인:"
sudo grep -r "server.domain.com" /etc/nginx/ 2>/dev/null | grep -v ".log" | head -5
echo ""

echo "===== 분석 완료 ====="
echo ""
echo "📝 문제 진단:"
echo "- HestiaCP가 server.domain.com 기본 페이지를 표시 중"
echo "- pay.sasori.dev 설정이 적용되지 않음"
echo "- 설정 우선순위 또는 include 순서 문제 가능성"
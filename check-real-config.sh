#!/bin/bash
# 실제 적용된 nginx 설정 디버깅

echo "===== nginx 설정 디버깅 ====="
echo ""

# 1. 현재 활성 설정 파일
echo "[1] 현재 /etc/nginx/conf.d/ 파일들:"
ls -la /etc/nginx/conf.d/*.conf 2>/dev/null
echo ""

# 2. domains 디렉토리 확인
echo "[2] domains 디렉토리:"
ls -la /etc/nginx/conf.d/domains/ 2>/dev/null || echo "디렉토리 없음"
echo ""

# 3. 00-pay-sasori-priority.conf 내용 확인
echo "[3] 우선순위 설정 파일 존재 여부:"
if [ -f "/etc/nginx/conf.d/00-pay-sasori-priority.conf" ]; then
    echo "✅ 파일 존재"
    echo "처음 10줄:"
    head -10 /etc/nginx/conf.d/00-pay-sasori-priority.conf
else
    echo "❌ 파일 없음!"
fi
echo ""

# 4. nginx가 실제로 로드하는 설정
echo "[4] nginx가 실제로 사용하는 서버 블록:"
sudo nginx -T 2>/dev/null | grep -A2 "server_name pay.sasori.dev" | head -20
echo ""

# 5. 443 포트 리스닝 확인
echo "[5] 443 포트를 듣고 있는 프로세스:"
sudo netstat -tlnp | grep :443
echo ""

# 6. HestiaCP 설정 경로
echo "[6] HestiaCP 실제 설정 파일:"
if [ -f "/home/admin/conf/web/server.domain.com/nginx.ssl.conf" ]; then
    echo "HestiaCP SSL 설정이 여전히 활성:"
    grep -E "listen|server_name|ssl_certificate" /home/admin/conf/web/server.domain.com/nginx.ssl.conf | head -10
fi
echo ""

echo "===== 진단 결과 ====="
echo ""
echo "📝 문제 분석:"
echo "1. 00-pay-sasori-priority.conf가 생성되었는지 확인"
echo "2. HestiaCP 설정이 여전히 우선 적용되는지 확인"
echo "3. nginx include 순서 문제 가능성"
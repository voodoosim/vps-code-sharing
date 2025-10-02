#!/bin/bash
# nginx 상태 확인 스크립트

echo "===== nginx 상태 확인 ====="
echo ""

# 1. nginx 프로세스 확인
echo "[1] nginx 프로세스 상태:"
ps aux | grep nginx | grep -v grep
echo ""

# 2. 포트 리스닝 확인
echo "[2] 포트 80/443 리스닝 상태:"
sudo netstat -tlnp | grep -E ':80|:443' || ss -tlnp | grep -E ':80|:443'
echo ""

# 3. 설정 파일 목록
echo "[3] 활성 nginx 설정 파일:"
ls -la /etc/nginx/conf.d/*.conf 2>/dev/null || echo "conf.d 디렉토리 없음"
ls -la /etc/nginx/sites-enabled/* 2>/dev/null || echo "sites-enabled 디렉토리 없음"
echo ""

# 4. SSL 인증서 확인
echo "[4] Let's Encrypt 인증서 상태:"
sudo certbot certificates 2>/dev/null || echo "certbot 명령어 사용 불가"
echo ""

# 5. 최근 로그 확인
echo "[5] 최근 nginx 에러 로그 (마지막 10줄):"
sudo tail -10 /var/log/nginx/error.log 2>/dev/null || echo "로그 파일 접근 권한 필요"
echo ""

# 6. HestiaCP/VestaCP 확인
echo "[6] 패널 설정 확인:"
if [ -d "/home/admin" ]; then
    echo "HestiaCP/VestaCP 감지됨"
    ls -la /home/admin/conf/web/*.conf 2>/dev/null | head -5 || echo "패널 설정 접근 불가"
else
    echo "패널이 설치되지 않음"
fi
echo ""

echo "===== 확인 완료 ====="
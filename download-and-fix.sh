#!/bin/bash
# 이 스크립트를 VPS에서 직접 실행하세요
# Windows 줄바꿈 문제를 자동으로 해결합니다

echo "Downloading and fixing line endings..."

# 스크립트 다운로드
curl -fsSL https://raw.githubusercontent.com/voodoosim/vps-code-sharing/main/simple-ssl.sh -o simple-ssl.sh

# dos2unix가 없으면 설치
if ! command -v dos2unix &> /dev/null; then
    echo "Installing dos2unix..."
    sudo apt-get install -y dos2unix
fi

# 줄바꿈 문자 수정
dos2unix simple-ssl.sh

# 실행 권한 부여
chmod +x simple-ssl.sh

echo "Fixed! Now run: sudo ./simple-ssl.sh"
#!/bin/bash
# VPS에서 실행하는 스크립트
# SSH 공개키를 안전하게 추가합니다

echo "===== Adding SSH Public Key ====="
echo ""

# SSH 디렉토리 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 공개키를 한 줄씩 입력받아 파일로 저장
echo "Paste your SSH public key (it should start with ssh-rsa):"
echo "After pasting, press Enter, then Ctrl+D to save"
echo ""

# 임시 파일로 저장
cat > /tmp/new_key.pub

# 키 형식 확인
if grep -q "^ssh-rsa" /tmp/new_key.pub; then
    # 줄바꿈 제거하고 한 줄로 만들기
    tr -d '\n' < /tmp/new_key.pub > /tmp/fixed_key.pub
    echo "" >> /tmp/fixed_key.pub  # 마지막에 줄바꿈 추가

    # authorized_keys에 추가
    cat /tmp/fixed_key.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    echo ""
    echo "===== SUCCESS ====="
    echo "SSH key has been added!"
    echo ""
    echo "Current keys:"
    cat ~/.ssh/authorized_keys

    # 임시 파일 삭제
    rm /tmp/new_key.pub /tmp/fixed_key.pub
else
    echo ""
    echo "===== ERROR ====="
    echo "Invalid SSH key format. Key should start with ssh-rsa"
    rm /tmp/new_key.pub
fi
#!/bin/bash
# 로컬 컴퓨터(Windows WSL 또는 Linux)에서 실행하는 스크립트
# SSH 키를 생성하고 VPS에 복사합니다

echo "===== SSH Key Setup (Local) ====="
echo ""

# VPS 정보 입력
read -p "Enter VPS IP address: " VPS_IP
read -p "Enter VPS username (default: developer): " VPS_USER
VPS_USER=${VPS_USER:-developer}
read -p "Enter VPS SSH port (default: 22): " VPS_PORT
VPS_PORT=${VPS_PORT:-22}

# SSH 키 저장 위치
SSH_KEY_PATH="$HOME/.ssh/id_rsa_vps"

# 1. SSH 디렉토리 생성
echo ""
echo "[1] Creating SSH directory..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 2. 기존 키 확인
if [ -f "$SSH_KEY_PATH" ]; then
    echo ""
    echo "SSH key already exists at $SSH_KEY_PATH"
    read -p "Do you want to overwrite it? (y/n): " OVERWRITE
    if [ "$OVERWRITE" != "y" ]; then
        echo "Using existing key..."
    else
        # 백업
        mv "$SSH_KEY_PATH" "$SSH_KEY_PATH.backup.$(date +%Y%m%d-%H%M%S)"
        mv "$SSH_KEY_PATH.pub" "$SSH_KEY_PATH.pub.backup.$(date +%Y%m%d-%H%M%S)" 2>/dev/null
    fi
fi

# 3. SSH 키 생성
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo ""
    echo "[2] Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -C "${VPS_USER}@${VPS_IP}"
else
    echo "[2] Using existing SSH key..."
fi

# 4. 공개 키 복사
echo ""
echo "[3] Copying public key to VPS..."
echo "You will need to enter your VPS password one last time:"

# ssh-copy-id 사용
ssh-copy-id -i "$SSH_KEY_PATH.pub" -p "$VPS_PORT" "${VPS_USER}@${VPS_IP}"

if [ $? -eq 0 ]; then
    echo ""
    echo "[4] Testing SSH key connection..."
    ssh -i "$SSH_KEY_PATH" -p "$VPS_PORT" -o PasswordAuthentication=no "${VPS_USER}@${VPS_IP}" "echo 'SSH key authentication successful!'"

    if [ $? -eq 0 ]; then
        echo ""
        echo "===== SUCCESS ====="
        echo "SSH key has been set up successfully!"
        echo ""
        echo "To connect to your VPS:"
        echo "ssh -i $SSH_KEY_PATH -p $VPS_PORT ${VPS_USER}@${VPS_IP}"
        echo ""
        echo "To make it easier, add this to ~/.ssh/config:"
        echo ""
        echo "Host vps"
        echo "    HostName $VPS_IP"
        echo "    User $VPS_USER"
        echo "    Port $VPS_PORT"
        echo "    IdentityFile $SSH_KEY_PATH"
        echo ""
        echo "Then you can connect with just: ssh vps"
        echo ""

        # SSH config 자동 추가 옵션
        read -p "Do you want to add this to ~/.ssh/config automatically? (y/n): " ADD_CONFIG
        if [ "$ADD_CONFIG" = "y" ]; then
            cat >> ~/.ssh/config << EOF

Host vps
    HostName $VPS_IP
    User $VPS_USER
    Port $VPS_PORT
    IdentityFile $SSH_KEY_PATH
EOF
            echo "Added to ~/.ssh/config!"
            echo "Now you can connect with: ssh vps"
        fi
    else
        echo "SSH key test failed. Please check the settings."
    fi
else
    echo ""
    echo "Failed to copy SSH key. Please check:"
    echo "1. VPS IP address is correct"
    echo "2. Username is correct"
    echo "3. Password is correct"
    echo "4. SSH port is correct"
fi
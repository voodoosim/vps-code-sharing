#!/bin/bash
# Windows WSL에서 빠르게 SSH 키 설정하는 스크립트

echo "===== Quick SSH Key Setup ====="
echo ""

# VPS 정보
VPS_IP=${1:-""}
VPS_USER=${2:-"developer"}

if [ -z "$VPS_IP" ]; then
    read -p "Enter VPS IP address: " VPS_IP
fi

# SSH 키 경로
KEY_PATH="$HOME/.ssh/id_rsa_vps"

# 1. SSH 키가 없으면 생성
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "${VPS_USER}@${VPS_IP}"
else
    echo "Using existing SSH key: $KEY_PATH"
fi

# 2. 공개 키 출력
echo ""
echo "===== YOUR PUBLIC KEY ====="
echo ""
cat "${KEY_PATH}.pub"
echo ""
echo "===== COPY ABOVE KEY ====="
echo ""

# 3. VPS 명령어 생성
echo "Now run these commands on your VPS:"
echo ""
echo "mkdir -p ~/.ssh"
echo "chmod 700 ~/.ssh"
echo "echo '$(cat ${KEY_PATH}.pub)' >> ~/.ssh/authorized_keys"
echo "chmod 600 ~/.ssh/authorized_keys"
echo ""

# 4. 연결 명령어
echo "After adding the key, connect with:"
echo "ssh -i $KEY_PATH ${VPS_USER}@${VPS_IP}"
echo ""

# 5. SSH config 추가
echo "To make it easier, add to ~/.ssh/config:"
echo ""
echo "Host vps"
echo "    HostName $VPS_IP"
echo "    User $VPS_USER"
echo "    IdentityFile $KEY_PATH"
echo ""
echo "Then connect with just: ssh vps"
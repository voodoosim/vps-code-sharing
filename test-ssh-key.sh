#!/bin/bash
# SSH 키 접속 테스트 스크립트

echo "===== SSH Key Test ====="
echo ""

# SSH 키 경로
KEY_PATH="$HOME/.ssh/id_rsa_vps"
VPS_IP="176.97.71.103"
VPS_USER="developer"

# 1. 키 파일 확인
if [ -f "$KEY_PATH" ]; then
    echo "[OK] SSH key found: $KEY_PATH"
else
    echo "[ERROR] SSH key not found: $KEY_PATH"
    exit 1
fi

# 2. 권한 확인
echo ""
echo "Checking file permissions..."
ls -la "$KEY_PATH"*

# 3. SSH 접속 테스트
echo ""
echo "Testing SSH connection..."
echo "Command: ssh -i $KEY_PATH -o PasswordAuthentication=no ${VPS_USER}@${VPS_IP} 'echo SUCCESS'"
echo ""

ssh -i "$KEY_PATH" -o PasswordAuthentication=no -o ConnectTimeout=5 "${VPS_USER}@${VPS_IP}" 'echo "SSH KEY LOGIN SUCCESS!"'

if [ $? -eq 0 ]; then
    echo ""
    echo "===== SUCCESS ====="
    echo "SSH key authentication is working!"
    echo ""
    echo "You can now connect with:"
    echo "ssh -i $KEY_PATH ${VPS_USER}@${VPS_IP}"
else
    echo ""
    echo "===== FAILED ====="
    echo "SSH key authentication failed."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if the public key was saved correctly on VPS:"
    echo "   ssh ${VPS_USER}@${VPS_IP} 'cat ~/.ssh/authorized_keys'"
    echo ""
    echo "2. Check SSH service on VPS:"
    echo "   ssh ${VPS_USER}@${VPS_IP} 'sudo systemctl status sshd'"
    echo ""
    echo "3. Check VPS SSH config allows key authentication:"
    echo "   ssh ${VPS_USER}@${VPS_IP} 'grep PubkeyAuthentication /etc/ssh/sshd_config'"
fi
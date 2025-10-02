#!/bin/bash
# VPS에서 실행하는 스크립트
# SSH 보안을 강화합니다 (비밀번호 인증 비활성화)

echo "===== SSH Security Hardening (VPS) ====="
echo ""
echo "WARNING: This will disable password authentication!"
echo "Make sure you have already set up SSH key authentication!"
echo ""

read -p "Have you successfully tested SSH key login? (yes/no): " CONFIRMED
if [ "$CONFIRMED" != "yes" ]; then
    echo "Please set up SSH key first using setup-ssh-key-local.sh"
    exit 1
fi

# 백업
echo "[1] Backing up SSH configuration..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)

# SSH 설정 수정
echo "[2] Modifying SSH configuration..."

# 임시 파일 생성
sudo tee /tmp/sshd_config_secure << 'EOF' > /dev/null
# SSH Security Configuration
# Modified by secure-vps-ssh.sh

# Basic Settings
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
LoginGraceTime 120
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 10

# Key Authentication (ENABLED)
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password Authentication (DISABLED)
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Other Authentication Methods (DISABLED)
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM yes

# Security Settings
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression delayed
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no

# Access Control
AllowUsers developer root
DenyGroups nogroup

# SFTP
Subsystem sftp /usr/lib/openssh/sftp-server

# Banner
Banner /etc/ssh/banner.txt
EOF

# 현재 설정과 병합 (기존 설정 중 필요한 것 보존)
echo "[3] Merging with existing configuration..."
sudo grep -E "^Port|^AllowUsers|^DenyUsers|^AllowGroups|^DenyGroups" /etc/ssh/sshd_config > /tmp/current_access_rules.txt 2>/dev/null

# Port 설정 확인
CURRENT_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' 2>/dev/null)
if [ ! -z "$CURRENT_PORT" ]; then
    sudo sed -i "s/^Port 22/Port $CURRENT_PORT/" /tmp/sshd_config_secure
    echo "Keeping current SSH port: $CURRENT_PORT"
fi

# AllowUsers 설정 확인 및 추가
CURRENT_USERS=$(grep "^AllowUsers" /etc/ssh/sshd_config | sed 's/AllowUsers //' 2>/dev/null)
if [ ! -z "$CURRENT_USERS" ]; then
    sudo sed -i "s/^AllowUsers.*/AllowUsers $CURRENT_USERS/" /tmp/sshd_config_secure
    echo "Keeping current allowed users: $CURRENT_USERS"
fi

# 배너 파일 생성
echo "[4] Creating login banner..."
sudo tee /etc/ssh/banner.txt << 'EOF' > /dev/null
############################################################
#                                                          #
#  Unauthorized access to this system is prohibited!      #
#                                                          #
#  All activities are monitored and logged.               #
#                                                          #
############################################################
EOF

# SSH 설정 테스트
echo "[5] Testing SSH configuration..."
sudo sshd -t -f /tmp/sshd_config_secure

if [ $? -eq 0 ]; then
    echo "[6] Configuration test passed. Applying new settings..."
    sudo mv /tmp/sshd_config_secure /etc/ssh/sshd_config
    sudo chmod 600 /etc/ssh/sshd_config

    # SSH 서비스 재시작
    echo "[7] Restarting SSH service..."
    sudo systemctl restart sshd || sudo systemctl restart ssh

    echo ""
    echo "===== SUCCESS ====="
    echo "SSH security has been hardened!"
    echo ""
    echo "Current settings:"
    echo "- Password authentication: DISABLED"
    echo "- Root login: DISABLED"
    echo "- Key authentication: ENABLED"
    echo "- Max auth tries: 3"
    if [ ! -z "$CURRENT_PORT" ]; then
        echo "- SSH Port: $CURRENT_PORT"
    else
        echo "- SSH Port: 22"
    fi
    echo ""
    echo "IMPORTANT: DO NOT close this session!"
    echo "Test SSH key login in a NEW terminal:"
    echo "ssh -i ~/.ssh/id_rsa_vps user@server"
    echo ""
    echo "If you get locked out, use console access to restore:"
    echo "sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config"
    echo "sudo systemctl restart sshd"
else
    echo ""
    echo "===== ERROR ====="
    echo "Configuration test failed! Not applying changes."
    echo "Check the error messages above."
    sudo rm /tmp/sshd_config_secure
    exit 1
fi
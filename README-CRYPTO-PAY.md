# 🤖 Telegram Crypto Pay 결제 시스템

Telegram 봇과 Crypto Pay API를 연동하여 암호화폐 결제를 받는 시스템입니다.

## 📋 시스템 구성

### 전체 구조
```
사용자 → Telegram Bot → Crypto Pay API → 결제
                ↑                          ↓
            봇 서버 ← Webhook ← 결제 완료 알림
```

### 주요 구성 요소

1. **Telegram Bot**: 사용자와 상호작용
2. **Crypto Pay API**: 암호화폐 결제 처리
3. **Webhook Server**: 결제 알림 수신 (포트 8080)
4. **Nginx**: HTTPS 프록시 및 SSL 처리
5. **Let's Encrypt**: 무료 SSL 인증서

## 🚀 새 VPS 빠른 설치

### 요구사항
- Ubuntu 22.04 LTS
- 도메인 (예: pay.yourdomain.com)
- Telegram Bot Token ([@BotFather](https://t.me/botfather)에서 생성)
- Crypto Pay API Token ([Crypto Pay](https://t.me/CryptoBot)에서 발급)

### 설치 명령어
```bash
# 1. 설치 스크립트 다운로드
wget https://raw.githubusercontent.com/voodoosim/vps-code-sharing/main/new-vps-setup.sh

# 2. 실행 권한 부여
chmod +x new-vps-setup.sh

# 3. 설치 실행
./new-vps-setup.sh

# 4. 환경변수 설정
nano .env
# 다음 값들을 실제 값으로 변경:
# - TELEGRAM_BOT_TOKEN
# - CRYPTO_PAY_API_TOKEN
# - ADMIN_USER_ID
# - DOMAIN_NAME

# 5. SSL 인증서 발급
sudo certbot --nginx -d your-domain.com

# 6. 서비스 시작
./start.sh
```

## 📁 파일 구조

```
~/crypto-pay-bot/
├── .env                    # 환경변수 (토큰, API 키)
├── webhook_server.py       # 웹훅 수신 서버
├── telegram_bot.py         # 텔레그램 봇
├── crypto-webhook.service  # systemd 서비스 (웹훅)
├── crypto-bot.service      # systemd 서비스 (봇)
├── nginx-config           # Nginx 설정
├── start.sh               # 시작 스크립트
└── logs/                  # 로그 디렉토리
    └── payments.log       # 결제 로그
```

## 🔧 설정

### Crypto Pay API 설정

1. [@CryptoBot](https://t.me/CryptoBot) 열기
2. `/start` → "Create App"
3. API Token 복사
4. Webhook URL 설정: `https://your-domain.com/crypto-pay/webhook`

### Telegram Bot 설정

1. [@BotFather](https://t.me/botfather) 열기
2. `/newbot` → 봇 생성
3. Token 복사
4. 봇 명령어 설정:
   ```
   /setcommands
   start - 시작
   pay - 결제하기
   status - 상태 확인
   ```

## 🛠️ 관리 명령어

### 서비스 관리
```bash
# 상태 확인
sudo systemctl status crypto-webhook
sudo systemctl status crypto-bot

# 재시작
sudo systemctl restart crypto-webhook
sudo systemctl restart crypto-bot

# 로그 확인
sudo journalctl -u crypto-webhook -f
sudo journalctl -u crypto-bot -f
```

### 테스트
```bash
# 웹훅 테스트
curl -X POST https://your-domain.com/crypto-pay/webhook \
  -H "Content-Type: application/json" \
  -d '{"update_type": "invoice_paid", "payload": {"invoice_id": "TEST"}}'

# 헬스체크
curl https://your-domain.com/health
```

## 📊 결제 처리 흐름

1. **인보이스 생성**
   - 사용자가 `/pay` 명령 실행
   - Crypto Pay API로 인보이스 생성 요청
   - 결제 링크를 사용자에게 전송

2. **결제 진행**
   - 사용자가 링크 클릭하여 결제
   - Crypto Pay에서 암호화폐 결제 처리

3. **결제 완료**
   - Crypto Pay가 webhook으로 알림 전송
   - webhook_server.py가 알림 수신
   - 데이터베이스 업데이트
   - 사용자에게 확인 메시지 전송

## 🔍 문제 해결

### 포트 확인
```bash
ss -tuln | grep 8080
```

### Nginx 에러
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### SSL 인증서 갱신
```bash
sudo certbot renew --dry-run  # 테스트
sudo certbot renew             # 실제 갱신
```

### 서비스가 시작되지 않을 때
```bash
# Python 패키지 확인
pip3 list | grep -E "aiohttp|telegram"

# 수동 실행으로 에러 확인
python3 webhook_server.py
```

## 📝 보안 권장사항

1. **방화벽 설정**
   ```bash
   sudo ufw allow 22/tcp   # SSH
   sudo ufw allow 80/tcp   # HTTP
   sudo ufw allow 443/tcp  # HTTPS
   sudo ufw enable
   ```

2. **Fail2ban 설정**
   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   ```

3. **환경변수 보안**
   ```bash
   chmod 600 .env  # 소유자만 읽기/쓰기
   ```

4. **정기 백업**
   ```bash
   # 데이터베이스와 로그 백업
   tar -czf backup-$(date +%Y%m%d).tar.gz payments.db logs/
   ```

## 📞 지원

문제가 발생하면:
1. 로그 확인: `sudo journalctl -u crypto-webhook -f`
2. GitHub Issues: https://github.com/voodoosim/vps-code-sharing/issues
3. Telegram 그룹: (그룹 링크 추가)

## 📜 라이센스

MIT License - 자유롭게 사용 가능
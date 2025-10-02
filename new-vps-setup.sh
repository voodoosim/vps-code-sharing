#!/bin/bash
# 새 VPS에서 Crypto Pay 결제 시스템 전체 설정
# Ubuntu 22.04 LTS 기준

set -e  # 에러 발생 시 즉시 중단

echo "====================================="
echo "🚀 Crypto Pay 결제 시스템 설치 시작"
echo "====================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 시스템 업데이트
echo -e "${GREEN}[1/10] 시스템 패키지 업데이트...${NC}"
sudo apt update && sudo apt upgrade -y

# 2. 필수 패키지 설치
echo -e "${GREEN}[2/10] 필수 패키지 설치...${NC}"
sudo apt install -y \
    python3 python3-pip python3-venv \
    nginx certbot python3-certbot-nginx \
    git curl wget \
    ufw fail2ban

# 3. Python 패키지 설치
echo -e "${GREEN}[3/10] Python 패키지 설치...${NC}"
pip3 install --upgrade pip
pip3 install \
    aiohttp \
    python-telegram-bot \
    asyncio \
    python-dotenv \
    cryptography

# 4. 프로젝트 디렉토리 생성
echo -e "${GREEN}[4/10] 프로젝트 디렉토리 생성...${NC}"
mkdir -p ~/crypto-pay-bot
cd ~/crypto-pay-bot

# 5. 환경변수 설정 파일 생성
echo -e "${GREEN}[5/10] 환경변수 파일 생성...${NC}"
cat > .env << 'EOF'
# Telegram Bot Token (BotFather에서 받은 토큰)
TELEGRAM_BOT_TOKEN=your_bot_token_here

# Crypto Pay API Token
CRYPTO_PAY_API_TOKEN=your_crypto_pay_token_here

# 관리자 Telegram User ID
ADMIN_USER_ID=your_telegram_user_id

# 서버 도메인 (예: pay.yourdomain.com)
DOMAIN_NAME=pay.yourdomain.com

# 데이터베이스 (선택사항)
DATABASE_URL=sqlite:///payments.db
EOF

echo -e "${YELLOW}⚠️  .env 파일을 편집하여 실제 값을 입력하세요!${NC}"

# 6. 웹훅 서버 생성
echo -e "${GREEN}[6/10] 웹훅 서버 코드 생성...${NC}"
cat > webhook_server.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import logging
import json
import os
from aiohttp import web
from datetime import datetime
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CryptoPayWebhook:
    def __init__(self):
        self.app = web.Application()
        self.setup_routes()

    def setup_routes(self):
        self.app.router.add_post('/crypto-pay/webhook', self.handle_webhook)
        self.app.router.add_get('/health', self.health_check)
        self.app.router.add_get('/', self.index)

    async def index(self, request):
        return web.Response(text="🤖 Crypto Pay Webhook Server Running")

    async def health_check(self, request):
        return web.json_response({'status': 'healthy'})

    async def handle_webhook(self, request):
        try:
            data = await request.json()
            update_type = data.get('update_type')

            logger.info(f"Webhook received: {update_type}")

            if update_type == 'invoice_paid':
                await self.process_payment(data['payload'])

            return web.json_response({'status': 'ok'})
        except Exception as e:
            logger.error(f"Error: {e}")
            return web.json_response({'error': str(e)}, status=500)

    async def process_payment(self, payload):
        """결제 처리 로직"""
        invoice_id = payload.get('invoice_id')
        amount = payload.get('amount')
        currency = payload.get('currency')

        logger.info(f"Payment: {amount} {currency} (Invoice: {invoice_id})")

        # TODO: 여기에 결제 처리 로직 추가
        # - 데이터베이스 업데이트
        # - 사용자에게 알림
        # - 서비스 활성화

    async def start(self):
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, '127.0.0.1', 8080)
        await site.start()
        logger.info("Webhook server started on port 8080")
        await asyncio.Event().wait()

if __name__ == '__main__':
    webhook = CryptoPayWebhook()
    asyncio.run(webhook.start())
EOF

# 7. Telegram 봇 메인 코드 생성
echo -e "${GREEN}[7/10] Telegram 봇 코드 생성...${NC}"
cat > telegram_bot.py << 'EOF'
#!/usr/bin/env python3
import os
import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
ADMIN_ID = int(os.getenv('ADMIN_USER_ID', '0'))

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """시작 명령어 처리"""
    await update.message.reply_text(
        "🤖 암호화폐 결제 봇입니다!\n"
        "💰 /pay - 결제하기\n"
        "📊 /status - 결제 상태 확인"
    )

async def pay(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """결제 명령어 처리"""
    # TODO: Crypto Pay API 호출하여 인보이스 생성
    await update.message.reply_text("💳 결제 링크를 생성 중입니다...")

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """상태 확인 명령어"""
    user_id = update.effective_user.id
    await update.message.reply_text(f"👤 User ID: {user_id}")

def main():
    """봇 실행"""
    app = Application.builder().token(BOT_TOKEN).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("pay", pay))
    app.add_handler(CommandHandler("status", status))

    logger.info("Bot started!")
    app.run_polling()

if __name__ == '__main__':
    main()
EOF

# 8. systemd 서비스 파일 생성
echo -e "${GREEN}[8/10] systemd 서비스 설정...${NC}"
cat > crypto-webhook.service << EOF
[Unit]
Description=Crypto Pay Webhook Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/crypto-pay-bot
ExecStart=/usr/bin/python3 $HOME/crypto-pay-bot/webhook_server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > crypto-bot.service << EOF
[Unit]
Description=Crypto Pay Telegram Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/crypto-pay-bot
ExecStart=/usr/bin/python3 $HOME/crypto-pay-bot/telegram_bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo cp crypto-webhook.service /etc/systemd/system/
sudo cp crypto-bot.service /etc/systemd/system/
sudo systemctl daemon-reload

# 9. Nginx 설정
echo -e "${GREEN}[9/10] Nginx 설정...${NC}"
cat > nginx-config << 'EOF'
server {
    listen 80;
    server_name DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name DOMAIN_NAME;

    # SSL 인증서 (Certbot이 자동 설정)
    # ssl_certificate /etc/letsencrypt/live/DOMAIN_NAME/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/DOMAIN_NAME/privkey.pem;

    location /crypto-pay/webhook {
        proxy_pass http://127.0.0.1:8080/crypto-pay/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /health {
        proxy_pass http://127.0.0.1:8080/health;
    }

    location / {
        proxy_pass http://127.0.0.1:8080/;
    }
}
EOF

# 10. 시작 스크립트
echo -e "${GREEN}[10/10] 시작 스크립트 생성...${NC}"
cat > start.sh << 'EOF'
#!/bin/bash
echo "🚀 서비스 시작..."

# 웹훅 서버 시작
sudo systemctl start crypto-webhook
sudo systemctl enable crypto-webhook

# 텔레그램 봇 시작
sudo systemctl start crypto-bot
sudo systemctl enable crypto-bot

# 상태 확인
sudo systemctl status crypto-webhook --no-pager
sudo systemctl status crypto-bot --no-pager

echo "✅ 모든 서비스가 시작되었습니다!"
echo ""
echo "로그 확인:"
echo "  sudo journalctl -u crypto-webhook -f"
echo "  sudo journalctl -u crypto-bot -f"
EOF

chmod +x start.sh

# 완료 메시지
echo ""
echo -e "${GREEN}====================================="
echo "✅ 설치 완료!"
echo "=====================================${NC}"
echo ""
echo -e "${YELLOW}다음 단계:${NC}"
echo "1. .env 파일 편집: nano .env"
echo "2. 도메인 DNS를 이 서버 IP로 설정"
echo "3. SSL 인증서 발급: sudo certbot --nginx -d your-domain.com"
echo "4. Nginx 설정 적용: sudo cp nginx-config /etc/nginx/sites-available/crypto-pay"
echo "5. Nginx 활성화: sudo ln -s /etc/nginx/sites-available/crypto-pay /etc/nginx/sites-enabled/"
echo "6. 서비스 시작: ./start.sh"
echo ""
echo -e "${GREEN}Crypto Pay API에 webhook URL 등록:${NC}"
echo "https://your-domain.com/crypto-pay/webhook"
echo ""
echo -e "${YELLOW}문제 해결:${NC}"
echo "- 포트 확인: ss -tuln | grep 8080"
echo "- 로그 확인: sudo journalctl -u crypto-webhook -f"
echo "- Nginx 테스트: sudo nginx -t"
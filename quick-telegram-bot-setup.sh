#!/bin/bash
# 🚀 Telegram Crypto Pay Bot 빠른 설정 스크립트
# 새 VPS에서 한번에 실행하는 설치 스크립트

set -e  # 에러 발생시 즉시 중단

echo "======================================"
echo "🤖 Telegram Crypto Pay Bot 설치 시작"
echo "======================================"
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 시스템 시간 동기화
echo -e "${GREEN}[1/8] 시스템 시간 동기화...${NC}"
sudo timedatectl set-ntp true
sudo timedatectl set-timezone Asia/Seoul
echo "현재 시간: $(date)"

# 2. 시스템 업데이트
echo -e "${GREEN}[2/8] 시스템 패키지 업데이트...${NC}"
sudo apt update && sudo apt upgrade -y

# 3. 필수 패키지 설치
echo -e "${GREEN}[3/8] 필수 패키지 설치...${NC}"
sudo apt install -y python3 python3-pip python3-venv screen

# 4. Python 가상환경 생성 (이미 있으면 스킵)
echo -e "${GREEN}[4/8] Python 가상환경 설정...${NC}"
if [ ! -d "$HOME/venv" ]; then
    python3 -m venv $HOME/venv
    echo "가상환경 생성 완료"
else
    echo "기존 가상환경 사용"
fi

# 가상환경 활성화
source $HOME/venv/bin/activate

# 5. Python 패키지 설치
echo -e "${GREEN}[5/8] Python 패키지 설치...${NC}"
pip install --upgrade pip
pip install python-telegram-bot aiohttp python-dotenv

# 6. bot.py 생성
echo -e "${GREEN}[6/8] Telegram 봇 코드 생성...${NC}"
cat > ~/bot.py << 'EOF'
#!/usr/bin/env python3
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes
import logging
import os
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# 봇 토큰 (환경변수 또는 직접 입력)
TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', '7834516558:AAH3X3xGrJKz8r_3eDz3L6P_UBDu9Cc5LcM')
CRYPTO_PAY_TOKEN = os.getenv('CRYPTO_PAY_TOKEN', 'your_crypto_pay_token_here')

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """시작 명령어 처리"""
    user = update.effective_user
    await update.message.reply_text(
        f"안녕 {user.first_name}! 🤖\n"
        f"크립토 페이 봇입니다.\n\n"
        f"사용 가능한 명령어:\n"
        f"/pay - 결제하기\n"
        f"/status - 상태 확인\n"
        f"/help - 도움말"
    )

async def pay(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """결제 명령어 처리"""
    await update.message.reply_text(
        "💳 결제 링크를 생성 중입니다...\n"
        "잠시만 기다려주세요."
    )
    # TODO: Crypto Pay API 호출하여 인보이스 생성

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """상태 확인"""
    user_id = update.effective_user.id
    await update.message.reply_text(
        f"📊 상태 정보\n"
        f"User ID: {user_id}\n"
        f"봇 상태: ✅ 정상 작동 중"
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """도움말"""
    await update.message.reply_text(
        "📚 도움말\n\n"
        "/start - 봇 시작\n"
        "/pay - 결제 링크 생성\n"
        "/status - 상태 확인\n"
        "/help - 이 도움말 보기"
    )

def main():
    """봇 실행"""
    # 애플리케이션 생성
    app = Application.builder().token(TOKEN).build()
    
    # 명령어 핸들러 등록
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("pay", pay))
    app.add_handler(CommandHandler("status", status))
    app.add_handler(CommandHandler("help", help_command))
    
    # 봇 시작
    logger.info("🚀 봇이 시작되었습니다!")
    print("봇이 실행 중입니다. Ctrl+C로 중단할 수 있습니다.")
    
    # 폴링 시작
    app.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
EOF

chmod +x ~/bot.py
echo "✅ bot.py 생성 완료"

# 7. webhook.py 생성
echo -e "${GREEN}[7/8] 웹훅 서버 코드 생성...${NC}"
cat > ~/webhook.py << 'EOF'
#!/usr/bin/env python3
from aiohttp import web
from datetime import datetime
import json
import logging
import os
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# 토큰
CRYPTO_PAY_TOKEN = os.getenv('CRYPTO_PAY_TOKEN', 'your_crypto_pay_token_here')

async def webhook(request):
    """Crypto Pay 웹훅 처리"""
    try:
        # 요청 데이터 파싱
        data = await request.json()
        logger.info(f"웹훅 수신: {json.dumps(data, indent=2)}")
        
        # 웹훅 타입 확인
        update_type = data.get("update_type")
        
        if update_type == "invoice_paid":
            # 결제 완료 처리
            invoice = data.get("payload", {})
            logger.info(f"💰 결제 완료!")
            logger.info(f"  - Invoice ID: {invoice.get('invoice_id')}")
            logger.info(f"  - Amount: {invoice.get('amount')} {invoice.get('currency')}")
            logger.info(f"  - User: {invoice.get('paid_by', {}).get('user', {}).get('username')}")
            
            # TODO: 데이터베이스 업데이트
            # TODO: 사용자에게 알림 전송
            
        elif update_type == "invoice_expired":
            logger.info("⏰ 인보이스 만료")
            
        return web.json_response({"status": "ok"})
        
    except Exception as e:
        logger.error(f"웹훅 처리 에러: {e}")
        return web.json_response({"error": str(e)}, status=500)

async def health(request):
    """헬스체크 엔드포인트"""
    return web.json_response({
        "status": "healthy",
        "timestamp": datetime.now().isoformat()
    })

async def index(request):
    """메인 페이지"""
    return web.Response(text="🤖 Crypto Pay Webhook Server Running")

# 앱 생성
app = web.Application()
app.router.add_post("/crypto-pay/webhook", webhook)
app.router.add_get("/health", health)
app.router.add_get("/", index)

if __name__ == "__main__":
    port = int(os.getenv('WEBHOOK_PORT', 8080))
    host = os.getenv('WEBHOOK_HOST', '127.0.0.1')
    
    logger.info(f"🚀 웹훅 서버 시작 - {host}:{port}")
    print(f"웹훅 서버가 http://{host}:{port} 에서 실행 중입니다.")
    
    web.run_app(app, host=host, port=port)
EOF

chmod +x ~/webhook.py
echo "✅ webhook.py 생성 완료"

# 8. .env 파일 생성
echo -e "${GREEN}[8/8] 환경변수 파일 생성...${NC}"
cat > ~/.env << 'EOF'
# Telegram Bot Token (BotFather에서 발급)
TELEGRAM_BOT_TOKEN=7834516558:AAH3X3xGrJKz8r_3eDz3L6P_UBDu9Cc5LcM

# Crypto Pay API Token (Crypto Bot에서 발급)
CRYPTO_PAY_TOKEN=your_crypto_pay_token_here

# Webhook 설정
WEBHOOK_HOST=127.0.0.1
WEBHOOK_PORT=8080

# 관리자 Telegram ID
ADMIN_USER_ID=your_telegram_id_here
EOF

echo "✅ .env 파일 생성 완료"

# 실행 스크립트 생성
cat > ~/start-bot.sh << 'EOF'
#!/bin/bash
# 봇 시작 스크립트

echo "🤖 Telegram Bot 시작..."
source ~/venv/bin/activate

# Screen 세션으로 봇 실행
screen -dmS telegram-bot bash -c "source ~/venv/bin/activate && python ~/bot.py"
echo "✅ Telegram Bot이 백그라운드에서 실행 중 (screen -r telegram-bot)"

# Webhook 서버 실행
screen -dmS webhook-server bash -c "source ~/venv/bin/activate && python ~/webhook.py"
echo "✅ Webhook 서버가 백그라운드에서 실행 중 (screen -r webhook-server)"

echo ""
echo "📊 실행 상태 확인:"
echo "  - Telegram Bot: screen -r telegram-bot"
echo "  - Webhook Server: screen -r webhook-server"
echo "  - 모든 Screen 세션 보기: screen -ls"
echo ""
echo "중단하려면 각 screen 세션에서 Ctrl+C"
EOF

chmod +x ~/start-bot.sh

# 테스트 스크립트 생성
cat > ~/test-webhook.sh << 'EOF'
#!/bin/bash
# 웹훅 테스트 스크립트

echo "🧪 웹훅 서버 테스트"
echo ""

echo "1. 헬스체크..."
curl -s http://localhost:8080/health | python3 -m json.tool

echo ""
echo "2. 테스트 웹훅 전송..."
curl -X POST http://localhost:8080/crypto-pay/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "update_type": "invoice_paid",
    "payload": {
      "invoice_id": "TEST-001",
      "amount": "100",
      "currency": "USDT",
      "paid_by": {
        "user": {
          "username": "testuser"
        }
      }
    }
  }' | python3 -m json.tool

echo ""
echo "✅ 테스트 완료"
EOF

chmod +x ~/test-webhook.sh

# 완료 메시지
echo ""
echo -e "${GREEN}======================================"
echo "✅ 설치 완료!"
echo "======================================${NC}"
echo ""
echo -e "${YELLOW}다음 단계:${NC}"
echo "1. 환경변수 설정: nano ~/.env"
echo "   - CRYPTO_PAY_TOKEN 입력"
echo "   - ADMIN_USER_ID 입력"
echo ""
echo "2. 봇 실행: ~/start-bot.sh"
echo ""
echo "3. 테스트: ~/test-webhook.sh"
echo ""
echo -e "${GREEN}Screen 명령어:${NC}"
echo "  - screen -ls : 실행 중인 세션 보기"
echo "  - screen -r telegram-bot : 봇 로그 보기"
echo "  - screen -r webhook-server : 웹훅 로그 보기"
echo "  - Ctrl+A, D : Screen에서 나가기 (백그라운드 유지)"
echo ""
echo -e "${YELLOW}문제 해결:${NC}"
echo "  - pip list : 설치된 패키지 확인"
echo "  - python ~/bot.py : 직접 실행으로 에러 확인"
echo "  - tail -f bot.log : 로그 실시간 확인"
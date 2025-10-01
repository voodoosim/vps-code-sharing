#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
텔레그램 스텔스 메시지 모니터링 시스템
개인 메시지만 포워딩 (그룹 메시지 제외)
"""

import asyncio
import logging
import requests
from datetime import datetime
from telethon import TelegramClient, events

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MessageForwarder:
    def __init__(self):
        # 메인 계정 정보
        self.api_id = '24413779'
        self.api_hash = '6f8a7e248b581b5159ea62ba3ca279fe'
        self.phone = '+888 0132 6974'

        # 봇 정보
        self.bot_token = '7722937739:AAGWjR37rUtbNaoCQ7ZhU7nUitt8N8fc4Fg'
        self.chat_id = None  # 봇에서 /start 명령으로 설정됨

        self.client = None

    async def start(self):
        """클라이언트 시작 및 설정"""
        try:
            logger.info("🚀 개인 메시지 모니터링 시작")

            # 기존 세션 파일 사용 (5월 1일에 생성한 것)
            self.client = TelegramClient('account1.session', self.api_id, self.api_hash)

            await self.client.start(phone=self.phone)

            if await self.client.is_user_authorized():
                logger.info("✅ 텔레그램 계정 로그인 성공")

                # 사용자 정보 확인
                me = await self.client.get_me()
                logger.info(f"👤 계정: {me.first_name} {me.last_name or ''}")

                # 메시지 핸들러 등록
                self.client.add_event_handler(self.message_handler, events.NewMessage)

                logger.info("📱 개일 메시지 포워딩 활성화")
                logger.info("💡 봇 '7722937739:AAGWjR37rUtbNaoCQ7ZhU7nUitt8N8fc4Fg'에서 /start 명령하세요")

                # 무한 실행
                await self.client.run_until_disconnected()

            else:
                logger.error("❌ 텔레그램 인증 실패")

        except Exception as e:
            logger.error(f"❌ 시스템 오류: {e}")
        finally:
            if self.client:
                await self.client.disconnect()

    async def message_handler(self, event):
        """새 메시지 수신 처리 - 개인 메시지만 포워딩"""
        try:
            message = event.message
            chat = await message.get_chat()

            # 🔹 개인 메시지만 필터링 (그룹/채널 제외)
            if hasattr(chat, 'title'):
                # 그룹이나 채널인 경우 무시
                logger.info(f"🚫 그룹 메시지 무시: {chat.title}")
                return

            # 발신자 정보
            sender = await message.get_sender()
            sender_name = getattr(sender, 'first_name', 'Unknown') or 'Unknown'
            if hasattr(sender, 'last_name') and sender.last_name:
                sender_name += f" {sender.last_name}"

            # 개인 메시지 내용 준비
            forward_text = f"📨 개인 메시지\n"
            forward_text += f"👤 발신자: {sender_name}\n"
            forward_text += f"⏰ 시간: {message.date.strftime('%Y-%m-%d %H:%M:%S')}\n"
            forward_text += f"📝 내용: {message.text or '[미디어/첨부파일]'}"

            # 로그 기록
            logger.info(f"📱 개인 메시지 수신: {sender_name} → {message.text[:50] if message.text else '[미디어]'}")

            # 봇으로 포워딩
            await self.send_to_bot(forward_text)

        except Exception as e:
            logger.error(f"❌ 메시지 처리 오류: {e}")

    async def send_to_bot(self, text):
        """봇 API를 통해 메시지 전송"""
        try:
            # chat_id가 설정되지 않은 경우 로그만 기록
            if not self.chat_id:
                logger.info("⚠️ chat_id가 설정되지 않았습니다. 봇에서 /start 명령을 실햙하세요")
                logger.info(f"📝 메시지 내용: {text}")
                return

            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            data = {
                'chat_id': self.chat_id,
                'text': text,
                'parse_mode': 'HTML'
            }

            response = requests.post(url, data=data)
            if response.status_code == 200:
                logger.info("✅ 봇으로 포워딩 완료")
            else:
                logger.error(f"❌ 봇 전송 실패: {response.status_code}")

        except Exception as e:
            logger.error(f"❌ 봇 전송 오류: {e}")

    def set_chat_id(self, chat_id):
        """채팅 ID 설정 (봇에서 호출)"""
        self.chat_id = chat_id
        logger.info(f"✅ 채팅 ID 설정: {chat_id}")

async def main():
    forwarder = MessageForwarder()
    await forwarder.start()

if __name__ == "__main__":
    logger.info("🎭 텔레그램 스텔스 메시지 모니터링 시스템")
    logger.info("📋 개인 메시지만 포워딩 (그룹 메시지 무시)")
    asyncio.run(main())
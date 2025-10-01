#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
텔레그램 폴링 방식 메시지 모니터링 시스템
15분마다 실행하여 쌓인 메시지 처리 + 중복 방지
"""

import asyncio
import logging
import requests
import json
import os
from datetime import datetime, timedelta
from telethon import TelegramClient

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PollingMessageForwarder:
    def __init__(self):
        # 메인 계정 정보
        self.api_id = '24413779'
        self.api_hash = '6f8a7e248b581b5159ea62ba3ca279fe'
        self.phone = '+888 0132 6974'

        # 봇 정보
        self.bot_token = '7722937739:AAGWjR37rUtbNaoCQ7ZhU7nUitt8N8fc4Fg'
        self.chat_id = None

        # 상태 파일들
        self.state_file = 'polling_state.json'
        self.client = None

    def load_state(self):
        """이전 상태 로드"""
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    return {
                        'last_check': datetime.fromisoformat(data.get('last_check', datetime.now().isoformat())),
                        'processed_ids': set(data.get('processed_ids', [])),
                        'chat_id': data.get('chat_id')
                    }
            except:
                pass
        
        return {
            'last_check': datetime.now() - timedelta(hours=1),  # 1시간 전부터
            'processed_ids': set(),
            'chat_id': None
        }

    def save_state(self, last_check, processed_ids, chat_id=None):
        """현재 상태 저장"""
        data = {
            'last_check': last_check.isoformat(),
            'processed_ids': list(processed_ids),
            'chat_id': chat_id or self.chat_id
        }
        with open(self.state_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    async def check_accumulated_messages(self):
        """쌓인 메시지들 확인 및 처리"""
        try:
            logger.info("🔍 쌓인 메시지 확인 시작")
            
            # 상태 로드
            state = self.load_state()
            last_check = state['last_check']
            processed_ids = state['processed_ids']
            self.chat_id = state['chat_id']
            
            logger.info(f"📅 마지막 확인: {last_check}")
            logger.info(f"📊 처리된 메시지: {len(processed_ids)}개")

            # 텔레그램 클라이언트 시작
            self.client = TelegramClient('account1.session', self.api_id, self.api_hash)
            await self.client.start(phone=self.phone)

            if not await self.client.is_user_authorized():
                logger.error("❌ 텔레그램 인증 실패")
                return

            new_messages_count = 0
            current_time = datetime.now()

            # 모든 대화 확인
            async for dialog in self.client.iter_dialogs():
                # 그룹/채널 제외 (개일 대화만)
                if hasattr(dialog.entity, 'title'):
                    continue

                try:
                    # 마지막 확인 시간 이후 메시지들 가져오기
                    messages = await self.client.get_messages(
                        dialog,
                        offset_date=last_check,
                        limit=50  # 최대 50개
                    )

                    # 시간순 정렬 (오래된 것부터)
                    for message in reversed(messages):
                        if message.id not in processed_ids and message.date > last_check:
                            await self.process_message(message)
                            processed_ids.add(message.id)
                            new_messages_count += 1

                except Exception as e:
                    logger.error(f"❌ 대화 처리 오류: {e}")
                    continue

            # 상태 저장
            self.save_state(current_time, processed_ids, self.chat_id)
            
            logger.info(f"✅ 완료: {new_messages_count}개 새 메시지 처리")
            
            # 오래된 ID 정리 (7일 이상된 것들)
            if len(processed_ids) > 1000:
                logger.info("🧹 오래된 메시지 ID 정리")
                # 최근 1000개만 유지
                recent_ids = set(list(processed_ids)[-1000:])
                self.save_state(current_time, recent_ids, self.chat_id)

        except Exception as e:
            logger.error(f"❌ 시스템 오류: {e}")
        finally:
            if self.client:
                await self.client.disconnect()

    async def process_message(self, message):
        """개일 메시지 처리"""
        try:
            # 발신자 정보
            sender = await message.get_sender()
            sender_name = getattr(sender, 'first_name', 'Unknown') or 'Unknown'
            if hasattr(sender, 'last_name') and sender.last_name:
                sender_name += f" {sender.last_name}"

            # 메시지 내용 준비
            forward_text = f"📨 개인 메시지\n"
            forward_text += f"👤 발신자: {sender_name}\n"
            forward_text += f"⏰ 시간: {message.date.strftime('%Y-%m-%d %H:%M:%S')}\n"
            forward_text += f"📝 내용: {message.text or '[미디어/첨부파일]'}"

            # 로그 기록
            logger.info(f"📱 새 메시지: {sender_name} - {message.text[:30] if message.text else '[미디어]'}...")

            # 봇으로 전송
            await self.send_to_bot(forward_text)

        except Exception as e:
            logger.error(f"❌ 메시지 처리 오류: {e}")

    async def send_to_bot(self, text):
        """봇 API를 통해 메시지 전송"""
        try:
            if not self.chat_id:
                logger.info("⚠️ chat_id 없음. 봇에서 /start 명령 필요")
                return

            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            data = {
                'chat_id': self.chat_id,
                'text': text,
                'parse_mode': 'HTML'
            }

            response = requests.post(url, data=data, timeout=10)
            if response.status_code == 200:
                logger.info("✅ 봇 전송 완료")
            else:
                logger.error(f"❌ 봇 전송 실패: {response.status_code}")

        except Exception as e:
            logger.error(f"❌ 봇 전송 오류: {e}")

async def main():
    forwarder = PollingMessageForwarder()
    await forwarder.check_accumulated_messages()

if __name__ == "__main__":
    logger.info("🎯 텔레그램 폴링 메시지 모니터링 시작")
    logger.info("📋 15분마다 실햙하여 쌓인 메시지 처리")
    asyncio.run(main())
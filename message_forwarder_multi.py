#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
텔레그램 폴링 방식 메시지 모니터링 시스템 (그룹 알림)
15분마다 실행하여 쌓인 메시지 처리 + 중복 방지 + 그룹에 알림 전송
여러 계정이 한 그룹에서 알림을 확인할 수 있음
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

class GroupNotificationForwarder:
    def __init__(self):
        # 메인 계정 정보
        self.api_id = '24413779'
        self.api_hash = '6f8a7e248b581b5159ea62ba3ca279fe'
        self.phone = '+888 0132 6974'

        # 봇 정보
        self.bot_token = '7722937739:AAGWjR37rUtbNaoCQ7ZhU7nUitt8N8fc4Fg'

        # 알림 그룹 chat_id (여러 계정이 들어있는 하나의 그룹)
        self.group_chat_id = None

        # 상태 파일들
        self.state_file = 'polling_state_group.json'
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
                        'group_chat_id': data.get('group_chat_id')
                    }
            except:
                pass

        return {
            'last_check': datetime.now() - timedelta(hours=1),  # 1시간 전부터
            'processed_ids': set(),
            'group_chat_id': None
        }

    def save_state(self, last_check, processed_ids, group_chat_id=None):
        """현재 상태 저장"""
        data = {
            'last_check': last_check.isoformat(),
            'processed_ids': list(processed_ids),
            'group_chat_id': group_chat_id or self.group_chat_id
        }
        with open(self.state_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def set_group_chat_id(self, group_chat_id):
        """알림 그룹 chat_id 설정"""
        self.group_chat_id = group_chat_id
        logger.info(f"✅ 알림 그룹 설정: {group_chat_id}")
        # 상태 파일에 즉시 저장
        state = self.load_state()
        self.save_state(state['last_check'], state['processed_ids'], self.group_chat_id)

    async def check_accumulated_messages(self):
        """쌓인 메시지들 확인 및 처리"""
        try:
            logger.info("🔍 쌓인 메시지 확인 시작")

            # 상태 로드
            state = self.load_state()
            last_check = state['last_check']
            processed_ids = state['processed_ids']
            self.group_chat_id = state['group_chat_id']

            logger.info(f"📅 마지막 확인: {last_check}")
            logger.info(f"📊 처리된 메시지: {len(processed_ids)}개")
            logger.info(f"👥 알림 그룹: {self.group_chat_id or '미설정'}")

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
                # 그룹/채널 제외 (개인 대화만)
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
            self.save_state(current_time, processed_ids, self.group_chat_id)

            logger.info(f"✅ 완료: {new_messages_count}개 새 메시지 처리")

            # 오래된 ID 정리 (1000개 이상)
            if len(processed_ids) > 1000:
                logger.info("🧹 오래된 메시지 ID 정리")
                # 최근 1000개만 유지
                recent_ids = set(list(processed_ids)[-1000:])
                self.save_state(current_time, recent_ids, self.group_chat_id)

        except Exception as e:
            logger.error(f"❌ 시스템 오류: {e}")
        finally:
            if self.client:
                await self.client.disconnect()

    async def process_message(self, message):
        """개인 메시지 처리 (향상된 발신자 정보 포함)"""
        try:
            # 발신자 정보 상세 수집
            sender = await message.get_sender()

            # 기본 정보
            sender_name = getattr(sender, 'first_name', 'Unknown') or 'Unknown'
            if hasattr(sender, 'last_name') and sender.last_name:
                sender_name += f" {sender.last_name}"

            # 사용자명 (@username)
            username = getattr(sender, 'username', None)
            username_text = f"@{username}" if username else "사용자명 없음"

            # 고유 ID
            user_id = getattr(sender, 'id', 'Unknown')

            # 전화번호 (있는 경우)
            phone = getattr(sender, 'phone', None)
            phone_text = f"+{phone}" if phone else "전화번호 비공개"

            # 메시지 내용 준비 (상세 정보 포함)
            forward_text = f"📨 개인 메시지 도착\n"
            forward_text += f"━━━━━━━━━━━━━━━━━━━━\n"
            forward_text += f"👤 발신자: {sender_name}\n"
            forward_text += f"🏷️ 사용자명: {username_text}\n"
            forward_text += f"🆔 고유번호: {user_id}\n"
            forward_text += f"📞 전화번호: {phone_text}\n"
            forward_text += f"⏰ 시간: {message.date.strftime('%Y-%m-%d %H:%M:%S')}\n"
            forward_text += f"━━━━━━━━━━━━━━━━━━━━\n"
            forward_text += f"📝 내용:\n{message.text or '[미디어/첨부파일]'}"

            # 로그 기록
            logger.info(f"📱 새 메시지: {sender_name} (@{username or 'N/A'}) - {message.text[:30] if message.text else '[미디어]'}...")

            # 그룹에 전송
            await self.send_to_group(forward_text)

        except Exception as e:
            logger.error(f"❌ 메시지 처리 오류: {e}")

    async def send_to_group(self, text):
        """알림 그룹에 메시지 전송"""
        try:
            if not self.group_chat_id:
                logger.info("⚠️ 알림 그룹 미설정. 봇을 그룹에 추가하고 그룹 ID를 설정해주세요")
                return

            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            data = {
                'chat_id': self.group_chat_id,
                'text': text,
                'parse_mode': 'HTML'
            }

            response = requests.post(url, data=data, timeout=10)
            if response.status_code == 200:
                logger.info("✅ 그룹 전송 완료")
            else:
                logger.error(f"❌ 그룹 전송 실패: {response.status_code}")

        except Exception as e:
            logger.error(f"❌ 그룹 전송 오류: {e}")

    def set_notification_group(self, group_chat_id):
        """알림 그룹 설정 (수동 호출용)"""
        self.set_group_chat_id(group_chat_id)
        print(f"✅ 알림 그룹 설정 완료: {group_chat_id}")
        print("이제 이 그룹에 개인 메시지 알림이 전송됩니다")

async def main():
    forwarder = GroupNotificationForwarder()

    # 명령행 인수로 그룹 설정 기능
    import sys
    if len(sys.argv) > 1:
        if sys.argv[1] == "setgroup" and len(sys.argv) > 2:
            group_chat_id = sys.argv[2]
            forwarder.set_notification_group(group_chat_id)
            return
        elif sys.argv[1] == "status":
            state = forwarder.load_state()
            print(f"현재 알림 그룹: {state['group_chat_id'] or '미설정'}")
            print(f"마지막 확인: {state['last_check']}")
            print(f"처리된 메시지: {len(state['processed_ids'])}개")
            return

    # 일반 폴링 실행
    await forwarder.check_accumulated_messages()

if __name__ == "__main__":
    logger.info("🎯 그룹 알림 텔레그램 폴링 메시지 모니터링 시작")
    logger.info("📋 15분마다 실행하여 쌓인 메시지 처리")
    logger.info("👥 한 그룹에서 여러 계정이 알림 확인")
    asyncio.run(main())
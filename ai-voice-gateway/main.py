
import os
import logging
import asyncio
import aiohttp
import uuid
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import Response

# --- NEW: Import the generated ARI client and models ---
from ari_client import Client
from ari_client.models import StasisStart

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ARI_URL = os.getenv("ARI_URL", "http://localhost:8088/")
ARI_APP_NAME = os.getenv("ARI_APP_NAME", "ai-call-center")
ARI_USER = os.getenv("ARI_USER", "ari_user")
ARI_PASSWORD = os.getenv("ARI_PASSWORD", "ari_password")
STT_API_URL = os.getenv("STT_API_URL", "http://stt-service:8001/stt")
LLM_API_URL = os.getenv("LLM_API_URL", "http://llm-service:8002/generate")
TTS_API_URL = os.getenv("TTS_API_URL", "http://tts-service:8003/tts")
# This gateway's own external URL, so Asterisk can reach it
GATEWAY_EXTERNAL_URL = os.getenv("GATEWAY_EXTERNAL_URL", "http://localhost:8000")

app = FastAPI()
# In-memory cache for TTS audio files
media_cache = {}

# --- Main Orchestration Logic ---

class CallHandler:
    def __init__(self, channel_id: str, client: Client):
        self.channel_id = channel_id
        self.client = client
        self.media_ws_ready = asyncio.Event()
        self.stt_buffer = bytearray()

    async def handle_call(self):
        try:
            logger.info(f"[{self.channel_id}] Answering call.")
            await self.client.channels.answer(channelId=self.channel_id)

            media_ws_url = f"{GATEWAY_EXTERNAL_URL.replace('http', 'ws')}/ws/media/{self.channel_id}"

            async with aiohttp.ClientSession() as http_session:
                logger.info(f"[{self.channel_id}] Starting media stream from Asterisk.")
                await self.client.channels.play_with_id(
                    channelId=self.channel_id,
                    playbackId=f"media-stream-{self.channel_id}",
                    media=f"sound:silence,media_uri={media_ws_url}"
                )

                await asyncio.wait_for(self.media_ws_ready.wait(), timeout=10.0)
                logger.info(f"[{self.channel_id}] Media WebSocket connected.")

                await self.play_tts(http_session, "Welcome! How may I help you today?")

                # The media websocket will now handle audio processing
                # This main handler task can wait until the call is hung up.
                while self.channel_id in app.state.call_handlers:
                    await asyncio.sleep(1)

        except Exception as e:
            logger.error(f"[{self.channel_id}] Error in call handler: {e}", exc_info=True)
        finally:
            self.cleanup()

    async def process_audio_chunk(self, audio_chunk: bytes, http_session: aiohttp.ClientSession):
        # This is a simplified VAD: send audio when we have a full second of it
        self.stt_buffer.extend(audio_chunk)
        if len(self.stt_buffer) > 16000 * 2: # ~1 second of 16-bit audio
            logger.info(f"[{self.channel_id}] Sending audio chunk for transcription.")
            audio_to_send = self.stt_buffer
            self.stt_buffer = bytearray() # Clear buffer

            try:
                transcription = await self.get_stt_transcription(http_session, audio_to_send)
                if transcription:
                    logger.info(f"[{self.channel_id}] Transcription: '{transcription}'")
                    llm_response = await self.get_llm_response(http_session, transcription)
                    if "transfer to human" in llm_response.lower():
                        await self.transfer_to_human(http_session)
                    else:
                        await self.play_tts(http_session, llm_response)
            except Exception as e:
                logger.error(f"[{self.channel_id}] Error processing audio chunk: {e}")

    async def get_stt_transcription(self, session: aiohttp.ClientSession, audio_bytes: bytes) -> str:
        form = aiohttp.FormData()
        form.add_field('file', audio_bytes, filename='audio.wav', content_type='audio/wav')
        async with session.post(STT_API_URL, data=form) as resp:
            data = await resp.json()
            return data.get("transcription", "").strip()

    async def get_llm_response(self, session: aiohttp.ClientSession, text: str) -> str:
        payload = {"prompt": text, "customer_id": self.channel_id}
        async with session.post(LLM_API_URL, json=payload) as resp:
            data = await resp.json()
            return data.get("text", "I am having trouble connecting.")

    async def play_tts(self, session: aiohttp.ClientSession, text: str):
        logger.info(f"[{self.channel_id}] Requesting TTS for: '{text}'")
        payload = {"text": text}
        async with session.post(TTS_API_URL, json=payload) as resp:
            if resp.status == 200:
                audio_data = await resp.read()
                playback_id = str(uuid.uuid4())
                media_cache[playback_id] = audio_data

                media_url = f"sound:{GATEWAY_EXTERNAL_URL}/media/{playback_id}"
                logger.info(f"[{self.channel_id}] Instructing Asterisk to play media from: {media_url}")
                await self.client.channels.play(channelId=self.channel_id, media=media_url)
            else:
                logger.error(f"[{self.channel_id}] Failed to get TTS audio.")

    async def transfer_to_human(self, session: aiohttp.ClientSession):
        logger.info(f"[{self.channel_id}] Transferring to human agent queue.")
        await self.play_tts(session, "Please wait while I transfer you.")
        await self.client.channels.continueInDialplan(channelId=self.channel_id, context='default', extension='human-queue')

    def cleanup(self):
        logger.info(f"[{self.channel_id}] Hanging up and cleaning up resources.")
        try:
            asyncio.create_task(self.client.channels.hangup(channelId=self.channel_id))
        except Exception: pass
        app.state.call_handlers.pop(self.channel_id, None)

# --- Media Endpoints ---
@app.get("/media/{playback_id}")
async def get_media(playback_id: str):
    if playback_id in media_cache:
        audio_data = media_cache.pop(playback_id) # One-time access
        return Response(content=audio_data, media_type="audio/wav")
    return Response(status_code=404)

@app.websocket("/ws/media/{channel_id}")
async def media_websocket_endpoint(websocket: WebSocket, channel_id: str):
    await websocket.accept()
    logger.info(f"[{channel_id}] Asterisk media WebSocket connected.")

    handler = app.state.call_handlers.get(channel_id)
    if not handler:
        await websocket.close(); return

    handler.media_ws_ready.set()

    try:
        async with aiohttp.ClientSession() as http_session:
            while True:
                message = await websocket.receive_bytes()
                await handler.process_audio_chunk(message, http_session)
    except WebSocketDisconnect:
        logger.warning(f"[{channel_id}] Asterisk media WebSocket disconnected.")
    finally:
        handler.cleanup()

# --- ARI Event Handling & Startup ---
async def ari_event_loop():
    while True:
        try:
            logger.info(f"Connecting to ARI at {ARI_URL}...")
            async with Client(base_url=ARI_URL, username=ARI_USER, password=ARI_PASSWORD) as client:
                app.state.ari_client = client
                logger.info("ARI connected. Listening for StasisStart events.")

                async for event in client.events.next_event(app=ARI_APP_NAME):
                    if isinstance(event, StasisStart):
                        channel_id = event.channel.id
                        if channel_id not in app.state.call_handlers:
                            handler = CallHandler(channel_id=channel_id, client=client)
                            app.state.call_handlers[channel_id] = handler
                            asyncio.create_task(handler.handle_call())
        except Exception as e:
            logger.error(f"ARI connection failed: {e}. Retrying in 5 seconds...")
            await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    app.state.call_handlers = {}
    asyncio.create_task(ari_event_loop())

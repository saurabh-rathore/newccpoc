
import os
import logging
import asyncio
import json
import base64
import aiohttp
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

# --- NEW: Import the generated ARI client and models ---
from ari_client import Client
from ari_client.models import StasisStart, Playback

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ARI_URL = os.getenv("ARI_URL", "http://localhost:8088/")
ARI_APP_NAME = os.getenv("ARI_APP_NAME", "ai-call-center")
ARI_USER = os.getenv("ARI_USER", "ari_user")
ARI_PASSWORD = os.getenv("ARI_PASSWORD", "ari_password")
STT_WS_URL = os.getenv("STT_WS_URL", "ws://localhost:8001/ws/stt")
LLM_API_URL = os.getenv("LLM_API_URL", "http://localhost:8002/generate")
TTS_API_URL = os.getenv("TTS_API_URL", "http://localhost:8003/tts") # Using HTTP for TTS now
GATEWAY_WS_URL_BASE = os.getenv("GATEWAY_WS_URL_BASE", "ws://localhost:8000/ws/media/")

app = FastAPI()

# --- Main Orchestration Logic ---

class CallHandler:
    def __init__(self, channel_id: str, client: Client):
        self.channel_id = channel_id
        self.client = client
        self.stt_ws = None
        self.media_ws_ready = asyncio.Event()

    async def handle_call(self):
        try:
            logger.info(f"[{self.channel_id}] Answering call.")
            await self.client.channels.answer(channelId=self.channel_id)

            # The media WebSocket URL that Asterisk will connect to
            media_ws_url = f"{GATEWAY_WS_URL_BASE}{self.channel_id}"

            async with aiohttp.ClientSession() as http_session, \
                 aiohttp.ClientSession().ws_connect(STT_WS_URL) as self.stt_ws:

                logger.info(f"[{self.channel_id}] Connected to STT service.")

                # Tell Asterisk to start sending us media
                await self.client.channels.play_with_id(
                    channelId=self.channel_id,
                    playbackId=f"media-stream-{self.channel_id}",
                    media=f"sound:silence,media_uri={media_ws_url}"
                )

                await asyncio.wait_for(self.media_ws_ready.wait(), timeout=10.0)
                logger.info(f"[{self.channel_id}] Media WebSocket connected and ready.")

                await self.play_tts(http_session, "Welcome! How can I help you today?")

                # Main loop: process transcriptions from STT
                async for stt_msg in self.stt_ws:
                    if stt_msg.type == aiohttp.WSMsgType.TEXT:
                        transcription = stt_msg.data.strip()
                        if not transcription:
                            continue

                        logger.info(f"[{self.channel_id}] Transcription: '{transcription}'")

                        llm_response = await self.get_llm_response(http_session, transcription)

                        if "transfer to human" in llm_response.lower():
                            await self.transfer_to_human(http_session)
                            break

                        await self.play_tts(http_session, llm_response)

        except Exception as e:
            logger.error(f"[{self.channel_id}] Error in call: {e}", exc_info=True)
        finally:
            logger.info(f"[{self.channel_id}] Hanging up and cleaning up resources.")
            try:
                await self.client.channels.hangup(channelId=self.channel_id)
            except Exception: pass
            app.state.call_handlers.pop(self.channel_id, None)

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
                # Use a unique ID for the playback
                playback_id = f"tts-playback-{self.channel_id}-{asyncio.get_running_loop().time()}"

                # Instead of streaming, we save to a temp file and play, which is simpler and more reliable for this setup
                temp_audio_path = f"/tmp/tts_{playback_id}.wav"
                with open(temp_audio_path, "wb") as f:
                    f.write(audio_data)

                logger.info(f"[{self.channel_id}] Playing TTS audio from {temp_audio_path}")
                await self.client.channels.play(channelId=self.channel_id, media=f"sound:{temp_audio_path.replace('.wav', '')}")
                os.remove(temp_audio_path) # Clean up the temp file
            else:
                logger.error(f"[{self.channel_id}] Failed to get TTS audio.")

    async def transfer_to_human(self, session: aiohttp.ClientSession):
        logger.info(f"[{self.channel_id}] Transferring to human agent queue.")
        await self.play_tts(session, "Please wait while I transfer you.")
        await self.client.channels.continueInDialplan(channelId=self.channel_id, context='default', extension='human-queue')


# --- Asterisk Media WebSocket ---
@app.websocket("/ws/media/{channel_id}")
async def media_websocket_endpoint(websocket: WebSocket, channel_id: str):
    await websocket.accept()
    logger.info(f"[{channel_id}] Asterisk media WebSocket connected.")

    handler = app.state.call_handlers.get(channel_id)
    if not handler:
        logger.error(f"[{channel_id}] No handler for this media stream.")
        await websocket.close()
        return

    handler.media_ws_ready.set()

    try:
        while True:
            message = await websocket.receive_bytes()
            # Forward the raw audio bytes directly to the STT service
            if handler.stt_ws and not handler.stt_ws.closed:
                await handler.stt_ws.send_bytes(message)

    except WebSocketDisconnect:
        logger.warning(f"[{channel_id}] Asterisk media WebSocket disconnected.")
    finally:
        handler.media_ws_ready.clear()


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


import os
import logging
import asyncio
import json
import base64
import aiohttp
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import websockets
import asterisk.ari

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ARI_URL = os.getenv("ARI_URL", "http://asterisk:8088/")
ARI_APP_NAME = os.getenv("ARI_APP_NAME", "ai-call-center")
ARI_USER = os.getenv("ARI_USER", "ari_user")
ARI_PASSWORD = os.getenv("ARI_PASSWORD", "ari_password")
STT_WS_URL = os.getenv("STT_WS_URL", "ws://stt-service:8001/ws/stt")
LLM_API_URL = os.getenv("LLM_API_URL", "http://llm-service:8002/generate")
TTS_WS_URL = os.getenv("TTS_WS_URL", "ws://tts-service:8003/ws/tts")
GATEWAY_WS_URL_BASE = os.getenv("GATEWAY_WS_URL_BASE", "ws://ai-voice-gateway:8000/ws/media/")

app = FastAPI()
ari_client = None

# --- Main Orchestration Logic ---

class CallHandler:
    def __init__(self, channel):
        self.channel = channel
        self.stt_ws = None
        self.tts_ws = None
        self.playback_active = asyncio.Event()
        self.media_ws_ready = asyncio.Event() # Event to signal media WebSocket connection

    def cleanup(self):
        """Remove this handler from the global list to prevent memory leaks."""
        app.state.call_handlers.pop(self.channel.id, None)
        logger.info(f"[{self.channel.id}] Call handler cleaned up.")

    async def handle_call(self):
        try:
            await self.channel.answer()
            logger.info(f"[{self.channel.id}] Call answered.")

            async with websockets.connect(STT_WS_URL) as self.stt_ws, \
                       websockets.connect(TTS_WS_URL) as self.tts_ws:

                logger.info(f"[{self.channel.id}] Connected to AI services.")

                media_ws_url = f"{GATEWAY_WS_URL_BASE}{self.channel.id}"
                await self.channel.play(media=f"sound:silence,media_uri={media_ws_url}", format="slin16")

                # Wait for the media WebSocket to connect back and be ready
                try:
                    await asyncio.wait_for(self.media_ws_ready.wait(), timeout=10.0)
                    logger.info(f"[{self.channel.id}] Media WebSocket is ready.")
                except asyncio.TimeoutError:
                    logger.error(f"[{self.channel.id}] Timed out waiting for media WebSocket.")
                    return # Exit the call

                await self.play_tts("Welcome to our automated service. How can I help you today?")

                await self.process_stt_and_generate_response()

        except Exception as e:
            logger.error(f"[{self.channel.id}] Error in call: {e}", exc_info=True)
        finally:
            logger.info(f"[{self.channel.id}] Hanging up call and cleaning up resources.")
            await self.channel.hangup()
            self.cleanup() # Ensure cleanup is called

    async def process_stt_and_generate_response(self):
        async for message in self.stt_ws:
            transcription = message.strip()
            if not transcription:
                continue

            logger.info(f"[{self.channel.id}] Transcription: '{transcription}'")
            self.playback_active.set()

            llm_response = await self.get_llm_response(transcription)

            if "transfer to human" in llm_response.lower():
                await self.transfer_to_human()
                break

            await self.play_tts(llm_response)

    async def get_llm_response(self, text):
        async with aiohttp.ClientSession() as session:
            payload = {"prompt": text, "customer_id": self.channel.id}
            async with session.post(LLM_API_URL, json=payload) as resp:
                data = await resp.json()
                return data.get("text", "I'm sorry, I'm having trouble.")

    async def play_tts(self, text):
        self.playback_active.clear()
        await self.tts_ws.send(text)
        async for audio_chunk in self.tts_ws:
            if self.playback_active.is_set():
                break
            media_ws = app.state.media_websockets.get(self.channel.id)
            if media_ws:
                payload = {"type": "binary", "data": base64.b64encode(audio_chunk).decode('utf-8')}
                await media_ws.send_text(json.dumps(payload))

    async def transfer_to_human(self):
        logger.info(f"[{self.channel.id}] Transferring to human agent queue.")
        await self.play_tts("Please wait while I transfer you to a human agent.")
        await self.channel.continueInDialplan(context='human-agent-queue-context', extension='human-queue')


# --- Asterisk Media WebSocket ---
@app.websocket("/ws/media/{channel_id}")
async def media_websocket_endpoint(websocket: WebSocket, channel_id: str):
    await websocket.accept()
    logger.info(f"[{channel_id}] Asterisk media WebSocket connected.")
    app.state.media_websockets[channel_id] = websocket

    handler = app.state.call_handlers.get(channel_id)
    if not handler:
        logger.error(f"[{channel_id}] No CallHandler found for this media stream.")
        await websocket.close()
        return

    # Signal that the media WebSocket is ready
    handler.media_ws_ready.set()

    try:
        while True:
            message = await websocket.receive_text()
            data = json.loads(message)
            if data['type'] == 'binary':
                audio_chunk = base64.b64decode(data['data'])
                if handler and handler.stt_ws:
                    await handler.stt_ws.send(audio_chunk)

    except WebSocketDisconnect:
        logger.warning(f"[{channel_id}] Asterisk media WebSocket disconnected.")
    finally:
        app.state.media_websockets.pop(channel_id, None)

# --- ARI Event Handling ---
async def on_stasis_start(channel, event):
    handler = CallHandler(channel)
    app.state.call_handlers[channel.id] = handler
    asyncio.create_task(handler.handle_call())

@app.on_event("startup")
async def startup_event():
    global ari_client
    app.state.media_websockets = {}
    app.state.call_handlers = {} # Use a dictionary for efficient lookup and removal

    while True:
        try:
            logger.info("Connecting to ARI...")
            ari_client = await asterisk.ari.connect(ARI_URL, ARI_USER, ARI_PASSWORD)

            async def on_channel_event_wrapper(channel, event):
                 await on_stasis_start(channel, event)

            ari_client.on_channel_event('StasisStart', on_channel_event_wrapper)

            logger.info("ARI connected and listeners set up.")
            break
        except Exception as e:
            logger.error(f"ARI connection failed: {e}. Retrying...")
            await asyncio.sleep(5)

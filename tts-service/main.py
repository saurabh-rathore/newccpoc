
import os
import logging
import asyncio
import io
import numpy as np
import torch
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from websockets.exceptions import ConnectionClosed
from TTS.api import TTS

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_NAME = os.getenv("TTS_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")

# --- Model Loading (with CPU fallback) ---
logger.info(f"Loading TTS model: {MODEL_NAME}")
try:
    # Auto-detect device
    device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {device}")

    # Initialize the TTS model on the selected device
    tts = TTS(MODEL_NAME).to(device)
    logger.info("TTS model loaded successfully.")
except Exception as e:
    logger.error(f"Failed to load TTS model: {e}", exc_info=True)
    exit(1)

app = FastAPI()

@app.websocket("/ws/tts")
async def websocket_tts_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("TTS WebSocket connection established.")
    try:
        while True:
            text_to_synthesize = await websocket.receive_text()
            logger.info(f"Received text for synthesis: '{text_to_synthesize}'")

            wav_chunks = tts.tts(text=text_to_synthesize)

            audio_np = np.array(wav_chunks, dtype=np.float32)
            audio_int16 = (audio_np * 32767).astype(np.int16)
            audio_bytes = audio_int16.tobytes()

            chunk_size = 2048
            for i in range(0, len(audio_bytes), chunk_size):
                chunk = audio_bytes[i:i+chunk_size]
                await websocket.send_bytes(chunk)
                await asyncio.sleep(0.01)

            logger.info(f"Finished streaming audio for: '{text_to_synthesize}'")

    except (WebSocketDisconnect, ConnectionClosed):
        logger.warning("TTS WebSocket disconnected.")
    except Exception as e:
        logger.error(f"An error occurred in the TTS WebSocket: {e}", exc_info=True)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "Text-to-Speech"}

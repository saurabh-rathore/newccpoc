
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

# Environment variables
MODEL_NAME = os.getenv("TTS_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")

# --- Model Loading ---
logger.info(f"Loading TTS model: {MODEL_NAME}")
try:
    # Check for CUDA availability
    device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {device}")

    # Initialize the TTS model
    tts = TTS(MODEL_NAME).to(device)
    logger.info("TTS model loaded successfully.")
except Exception as e:
    logger.error(f"Failed to load TTS model: {e}", exc_info=True)
    exit(1)

app = FastAPI()

@app.websocket("/ws/tts")
async def websocket_tts_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for real-time Text-to-Speech.
    Receives text and streams back synthesized raw PCM audio chunks.
    """
    await websocket.accept()
    logger.info("TTS WebSocket connection established.")
    try:
        while True:
            # Receive text from the gateway
            text_to_synthesize = await websocket.receive_text()
            logger.info(f"Received text for synthesis: '{text_to_synthesize}'")

            # Synthesize the audio from the text
            # The tts() method returns a list of float values (waveform)
            wav_chunks = tts.tts(text=text_to_synthesize)

            # Convert the waveform to 16-bit PCM bytes
            # Asterisk typically expects SLN16 (16-bit Signed Linear, 16kHz)
            # The model's sample rate should be checked, but we assume it's compatible
            # and we are sending raw PCM data.
            audio_np = np.array(wav_chunks, dtype=np.float32)
            audio_int16 = (audio_np * 32767).astype(np.int16)
            audio_bytes = audio_int16.tobytes()

            # Stream the audio back in chunks
            chunk_size = 2048  # Send 2KB chunks
            for i in range(0, len(audio_bytes), chunk_size):
                chunk = audio_bytes[i:i+chunk_size]
                await websocket.send_bytes(chunk)
                # Small sleep to prevent overwhelming the client buffer
                await asyncio.sleep(0.01)

            logger.info(f"Finished streaming audio for: '{text_to_synthesize}'")

    except (WebSocketDisconnect, ConnectionClosed):
        logger.warning("TTS WebSocket disconnected.")
    except Exception as e:
        logger.error(f"An error occurred in the TTS WebSocket: {e}", exc_info=True)

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "Text-to-Speech"}

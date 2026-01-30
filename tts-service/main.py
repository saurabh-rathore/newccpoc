
import os
import logging
import io
import wave
import torch
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from TTS.api import TTS

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_NAME = os.getenv("TTS_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")

# --- Model Loading (with CPU fallback) ---
logger.info(f"Loading TTS model: {MODEL_NAME}")
try:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Using device: {device}")

    tts = TTS(MODEL_NAME).to(device)
    logger.info("TTS model loaded successfully.")
except Exception as e:
    logger.error(f"Failed to load TTS model: {e}", exc_info=True)
    exit(1)

app = FastAPI()

class TTSRequest(BaseModel):
    text: str

@app.post("/tts")
async def http_tts_endpoint(request: TTSRequest):
    """
    Accepts text and returns the synthesized speech as a WAV audio file.
    """
    try:
        logger.info(f"Received text for synthesis: '{request.text}'")

        # Synthesize the audio
        wav_chunks = tts.tts(text=request.text)

        # The output is a list of integers, we need to convert it to bytes
        # in a proper WAV format.
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2) # 16-bit
            wf.setframerate(22050) # Coqui TTS default sample rate

            # Convert float waveform to 16-bit PCM
            pcm_data = (np.array(wav_chunks) * 32767).astype(np.int16)
            wf.writeframes(pcm_data.tobytes())

        audio_bytes = buffer.getvalue()
        logger.info(f"Synthesized audio of size: {len(audio_bytes)} bytes")

        return Response(content=audio_bytes, media_type="audio/wav")

    except Exception as e:
        logger.error(f"Error during TTS processing: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to synthesize audio.")

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "Text-to-Speech"}

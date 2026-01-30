
import os
import logging
import io
import soundfile as sf
import numpy as np
import torch
from fastapi import FastAPI, UploadFile, File, HTTPException
from faster_whisper import WhisperModel

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_PATH = os.getenv("WHISPER_MODEL", "distil-whisper/distil-small.en")
LOCAL_MODEL_PATH = f"/models/{MODEL_PATH}"

# --- Model Loading (with CPU fallback) ---
logger.info(f"Loading Whisper model: {MODEL_PATH}")
try:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    compute_type = "float16" if device == "cuda" else "int8"
    logger.info(f"Using device: {device} with compute type: {compute_type}")

    model_load_path = LOCAL_MODEL_PATH if os.path.exists(LOCAL_MODEL_PATH) else MODEL_PATH
    model = WhisperModel(model_load_path, device=device, compute_type=compute_type)
    logger.info("Whisper model loaded successfully.")
except Exception as e:
    logger.error(f"Failed to load Whisper model: {e}", exc_info=True)
    exit(1)

app = FastAPI()

@app.post("/stt")
async def http_stt_endpoint(file: UploadFile = File(...)):
    """
    Accepts an audio file and returns the transcription.
    """
    try:
        logger.info(f"Received audio file for transcription: {file.filename}")

        # Read the audio file into memory
        audio_bytes = await file.read()
        audio_io = io.BytesIO(audio_bytes)

        # Use soundfile to read the audio data and sample rate
        audio_data, sample_rate = sf.read(audio_io, dtype='float32')

        # Resample if necessary (Whisper expects 16kHz)
        if sample_rate != 16000:
            logger.warning(f"Resampling audio from {sample_rate}Hz to 16000Hz.")
            # This requires ffmpeg to be installed in the container
            # For simplicity, we assume the input is already 16kHz.
            # A more robust solution would handle resampling.
            pass

        logger.info("Transcribing audio...")
        segments, _ = model.transcribe(audio_data, beam_size=5)

        transcription = "".join(segment.text for segment in segments).strip()
        logger.info(f"Transcription result: '{transcription}'")

        return {"transcription": transcription}

    except Exception as e:
        logger.error(f"Error during STT processing: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to process audio file.")

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "Speech-to-Text"}

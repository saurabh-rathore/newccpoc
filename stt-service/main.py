
import os
import logging
import io
import soundfile as sf
import numpy as np
import webrtcvad
import torch
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from websockets.exceptions import ConnectionClosed
from faster_whisper import WhisperModel

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_PATH = os.getenv("WHISPER_MODEL", "distil-whisper/distil-small.en")
LOCAL_MODEL_PATH = f"/models/{MODEL_PATH}"
VAD_AGGRESSIVENESS = int(os.getenv("VAD_AGGRESSIVENESS", 3))
VAD_FRAME_MS = int(os.getenv("VAD_FRAME_MS", 30))
VAD_SAMPLE_RATE = 16000
VAD_FRAME_SAMPLES = int(VAD_SAMPLE_RATE * (VAD_FRAME_MS / 1000.0))

# --- Model Loading (with CPU fallback) ---
logger.info(f"Loading Whisper model: {MODEL_PATH}")
try:
    # Auto-detect device
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
vad = webrtcvad.Vad(VAD_AGGRESSIVENESS)

class VadWrapper:
    def __init__(self):
        self.reset()

    def reset(self):
        self.speech_buffer = bytearray()
        self.triggered = False
        self.silence_frames = 0

    def process_audio(self, audio_chunk):
        is_speech = vad.is_speech(audio_chunk, VAD_SAMPLE_RATE)

        if is_speech:
            self.speech_buffer.extend(audio_chunk)
            self.triggered = True
            self.silence_frames = 0
        elif self.triggered:
            self.speech_buffer.extend(audio_chunk)
            self.silence_frames += 1
            if self.silence_frames > 10:
                utterance = self.speech_buffer
                self.reset()
                return utterance
        return None

@app.websocket("/ws/stt")
async def websocket_stt_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("STT WebSocket connection established.")
    vad_wrapper = VadWrapper()

    try:
        while True:
            audio_data = await websocket.receive_bytes()

            for i in range(0, len(audio_data), VAD_FRAME_SAMPLES * 2):
                chunk = audio_data[i:i + VAD_FRAME_SAMPLES * 2]
                if len(chunk) < VAD_FRAME_SAMPLES * 2:
                    continue

                utterance_bytes = vad_wrapper.process_audio(chunk)

                if utterance_bytes:
                    logger.info(f"Detected utterance of {len(utterance_bytes)} bytes.")
                    audio_np = np.frombuffer(utterance_bytes, dtype=np.int16).astype(np.float32) / 32768.0

                    segments, _ = model.transcribe(audio_np, beam_size=5)
                    transcription = "".join(segment.text for segment in segments).strip()

                    if transcription:
                        logger.info(f"Transcription: '{transcription}'")
                        await websocket.send_text(transcription)

    except (WebSocketDisconnect, ConnectionClosed):
        logger.warning("STT WebSocket disconnected.")
    except Exception as e:
        logger.error(f"An error occurred in the STT WebSocket: {e}", exc_info=True)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "Speech-to-Text"}

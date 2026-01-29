
import os
import logging
import aiohttp
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

STT_API_URL = os.getenv("STT_API_URL", "http://stt-service:8001/stt")
LLM_API_URL = os.getenv("LLM_API_URL", "http://llm-service:8002/generate")
TTS_API_URL = os.getenv("TTS_API_URL", "http://tts-service:8003/tts")

app = FastAPI()

@app.post("/process-voice-note")
async def process_voice_note(audio_file: UploadFile = File(...)):
    """
    This endpoint accepts an audio file, processes it through the AI pipeline,
    and returns the synthesized audio response.
    """
    try:
        # 1. Read the uploaded audio file content
        audio_bytes = await audio_file.read()
        logger.info(f"Received audio file of size: {len(audio_bytes)} bytes")

        async with aiohttp.ClientSession() as session:
            # 2. Send audio to STT service
            logger.info("Sending audio to Speech-to-Text service...")
            stt_form = aiohttp.FormData()
            stt_form.add_field('file', audio_bytes, filename=audio_file.filename, content_type=audio_file.content_type)

            async with session.post(STT_API_URL, data=stt_form) as stt_response:
                if stt_response.status != 200:
                    logger.error(f"STT service returned error: {stt_response.status}")
                    return Response(content="Error in STT service", status_code=500)
                stt_data = await stt_response.json()
                transcription = stt_data.get("transcription", "").strip()
                logger.info(f"Received transcription: '{transcription}'")

            if not transcription:
                return Response(content="Could not understand the audio.", status_code=400)

            # 3. Send transcription to LLM service
            logger.info("Sending transcription to Language Model service...")
            llm_payload = {"prompt": transcription, "customer_id": "audio-file-test"}
            async with session.post(LLM_API_URL, json=llm_payload) as llm_response:
                if llm_response.status != 200:
                    logger.error(f"LLM service returned error: {llm_response.status}")
                    return Response(content="Error in LLM service", status_code=500)
                llm_data = await llm_response.json()
                llm_text_response = llm_data.get("text", "I'm sorry, I had a problem.")
                logger.info(f"Received LLM response: '{llm_text_response}'")

            # 4. Send LLM response to TTS service
            logger.info("Sending LLM response to Text-to-Speech service...")
            tts_payload = {"text": llm_text_response}
            async with session.post(TTS_API_URL, json=tts_payload) as tts_response:
                if tts_response.status != 200:
                    logger.error(f"TTS service returned error: {tts_response.status}")
                    return Response(content="Error in TTS service", status_code=500)
                tts_audio_response = await tts_response.read()
                logger.info(f"Received synthesized audio of size: {len(tts_audio_response)} bytes")

            # 5. Return the final synthesized audio
            return Response(content=tts_audio_response, media_type="audio/wav")

    except Exception as e:
        logger.error(f"An error occurred: {e}", exc_info=True)
        return Response(content="An internal error occurred.", status_code=500)

@app.get("/health")
async def health_check():
    return {"status": "ok"}

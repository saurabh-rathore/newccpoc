
import os
import logging
import torch
from fastapi import FastAPI
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
from auto_gptq import AutoGPTQForCausalLM
from qdrant_client import QdrantClient, models
from sentence_transformers import SentenceTransformer

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Device Selection ---
DEVICE = "cuda:0" if torch.cuda.is_available() else "cpu"
logger.info(f"Using device: {DEVICE}")

# --- Model and Client Loading ---
MODEL_PATH_GPU = os.getenv("LLM_MODEL", "TheBloke/Mixtral-8x7B-Instruct-v0.1-GPTQ")
LOCAL_MODEL_PATH_GPU = f"/models/{MODEL_PATH_GPU}"
MODEL_PATH_CPU = "distilgpt2" # Smaller model for CPU-only testing

QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
QDRANT_COLLECTION = "call_center_kb"

logger.info("Initializing models and clients...")
try:
    if DEVICE == "cuda:0":
        logger.info(f"Loading GPU model: {MODEL_PATH_GPU}")
        model_load_path = LOCAL_MODEL_PATH_GPU if os.path.exists(LOCAL_MODEL_PATH_GPU) else MODEL_PATH_GPU
        tokenizer = AutoTokenizer.from_pretrained(model_load_path, use_fast=True)
        model = AutoGPTQForCausalLM.from_quantized(
            model_load_path,
            use_safetensors=True,
            trust_remote_code=True,
            device=DEVICE,
            use_triton=False,
            quantize_config=None
        )
    else:
        logger.warning("GPU not found. Loading smaller CPU model (distilgpt2).")
        logger.warning("Responses will be basic and not representative of production quality.")
        tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH_CPU)
        model = AutoModelForCausalLM.from_pretrained(MODEL_PATH_CPU)

    embedding_model = SentenceTransformer(EMBEDDING_MODEL, device=DEVICE)
    qdrant_client = QdrantClient(url=QDRANT_URL)

    logger.info("Models and clients initialized successfully.")
except Exception as e:
    logger.error(f"Failed to initialize models or clients: {e}", exc_info=True)
    exit(1)

# --- Qdrant Setup (only if not in CPU mode) ---
if DEVICE != "cpu":
    try:
        # (Same Qdrant setup logic as before)
        collections = qdrant_client.get_collections().collections
        if not any(c.name == QDRANT_COLLECTION for c in collections):
            qdrant_client.recreate_collection(
                collection_name=QDRANT_COLLECTION,
                vectors_config=models.VectorParams(
                    size=embedding_model.get_sentence_embedding_dimension(),
                    distance=models.Distance.COSINE
                )
            )
            qdrant_client.upsert(
                collection_name=QDRANT_COLLECTION,
                points=[
                    models.PointStruct(id=1, vector=embedding_model.encode("Your bill is due on the 25th of each month.").tolist(), payload={"text": "The billing cycle ends and payment is due on the 25th of every month."}),
                    models.PointStruct(id=2, vector=embedding_model.encode("How do I reset my password?").tolist(), payload={"text": "You can reset your account password by visiting our website and clicking the 'Forgot Password' link."}),
                    models.PointStruct(id=3, vector=embedding_model.encode("What are the international calling rates?").tolist(), payload={"text": "International calling rates vary by country. For specific rates, please say the country you wish to call. If the user asks for a transfer, respond with 'transfer to human'."}),
                ],
                wait=True
            )
    except Exception as e:
        logger.warning(f"Failed to set up Qdrant collection: {e}")

app = FastAPI()

class GenerationRequest(BaseModel):
    prompt: str
    customer_id: str

class GenerationResponse(BaseModel):
    text: str

@app.post("/generate", response_model=GenerationResponse)
async def generate_text(request: GenerationRequest):
    logger.info(f"Received request for customer {request.customer_id}")

    if DEVICE == "cpu":
        # Simplified logic for CPU mode
        full_prompt = request.prompt
        input_ids = tokenizer.encode(full_prompt, return_tensors="pt")
        output = model.generate(input_ids, max_length=50)
        response_text = tokenizer.decode(output[0], skip_special_tokens=True)
    else:
        # Full RAG logic for GPU mode
        query_embedding = embedding_model.encode(request.prompt).tolist()
        search_results = qdrant_client.search(collection_name=QDRANT_COLLECTION, query_vector=query_embedding, limit=1, score_threshold=0.7)
        context = ""
        if search_results:
            context = "Context: " + search_results[0].payload['text']

        full_prompt = f"<s>[INST] {context}\n\nQuestion: {request.prompt} [/INST]"
        input_ids = tokenizer(full_prompt, return_tensors="pt").input_ids.to(DEVICE)
        output = model.generate(inputs=input_ids, temperature=0.7, max_new_tokens=256)
        response_text = tokenizer.decode(output[0], skip_special_tokens=True).split('[/INST]')[-1].strip()

    logger.info(f"Generated response: {response_text}")
    return GenerationResponse(text=response_text)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "Language Model"}

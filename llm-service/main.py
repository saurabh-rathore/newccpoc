
import os
import logging
import torch
from fastapi import FastAPI
from pydantic import BaseModel
from transformers import AutoTokenizer
from auto_gptq import AutoGPTQForCausalLM
from qdrant_client import QdrantClient, models
from sentence_transformers import SentenceTransformer

# --- Configuration ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_PATH = os.getenv("LLM_MODEL", "TheBloke/Mixtral-8x7B-Instruct-v0.1-GPTQ")
LOCAL_MODEL_PATH = f"/models/{MODEL_PATH}"
QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
QDRANT_COLLECTION = "call_center_kb"

# --- Model and Client Loading ---
logger.info("Initializing models and clients...")
try:
    # Determine the model path
    model_load_path = LOCAL_MODEL_PATH if os.path.exists(LOCAL_MODEL_PATH) else MODEL_PATH
    logger.info(f"Loading model from: {model_load_path}")

    # Load Tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_load_path, use_fast=True)

    # Load Quantized LLM Model using AutoGPTQ
    model = AutoGPTQForCausalLM.from_quantized(
        model_load_path,
        use_safetensors=True,
        trust_remote_code=True,
        device="cuda:0",
        use_triton=False, # Triton can be faster but less stable
        quantize_config=None # The model is already quantized
    )
    logger.info("Quantized LLM model loaded successfully.")

    # Embedding Model
    embedding_model = SentenceTransformer(EMBEDDING_MODEL, device="cuda" if torch.cuda.is_available() else "cpu")
    logger.info("Embedding model loaded successfully.")

    # Qdrant Client
    qdrant_client = QdrantClient(url=QDRANT_URL)
    logger.info("Qdrant client initialized successfully.")

except Exception as e:
    logger.error(f"Failed to initialize models or clients: {e}", exc_info=True)
    exit(1)

# --- Qdrant Setup ---
# (Same as before)
try:
    collections = qdrant_client.get_collections().collections
    if not any(c.name == QDRANT_COLLECTION for c in collections):
        logger.info(f"Creating Qdrant collection: {QDRANT_COLLECTION}")
        qdrant_client.recreate_collection(
            collection_name=QDRANT_COLLECTION,
            vectors_config=models.VectorParams(
                size=embedding_model.get_sentence_embedding_dimension(),
                distance=models.Distance.COSINE
            )
        )
        logger.info("Uploading dummy knowledge base data to Qdrant...")
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

    # RAG logic (same as before)
    query_embedding = embedding_model.encode(request.prompt).tolist()
    search_results = qdrant_client.search(collection_name=QDRANT_COLLECTION, query_vector=query_embedding, limit=1, score_threshold=0.7)
    context = ""
    if search_results:
        context = "Context: " + search_results[0].payload['text']

    full_prompt = f"<s>[INST] {context}\n\nQuestion: {request.prompt} [/INST]"

    # Generate response
    input_ids = tokenizer(full_prompt, return_tensors="pt").input_ids.cuda()
    output = model.generate(inputs=input_ids, temperature=0.7, max_new_tokens=256)
    response_text = tokenizer.decode(output[0], skip_special_tokens=True).split('[/INST]')[-1].strip()

    logger.info(f"Generated response: {response_text}")

    return GenerationResponse(text=response_text)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "Language Model"}

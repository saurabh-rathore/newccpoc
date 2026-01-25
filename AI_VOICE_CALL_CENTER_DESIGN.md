
# AI-Powered Voice Call Center for Telecom - Design Document

## 1. High-Level Architecture Diagram

```
+-----------------+      +----------------------+      +---------------------+
|                 |      |                      |      |                     |
|  Asterisk PBX   |<---->|  AI Voice Gateway    |<---->|  Speech-to-Text     |
| (Call Handling) |      | (FastAPI, ARI/AGI)   |      |  (Whisper)          |
|                 |      |                      |      |                     |
+-----------------+      +----------------------+      +----------+----------+
       ^                                                       |
       |                                                       v
+-----------------+      +----------------------+      +----------+----------+
|                 |      |                      |      |                     |
|  Human Agent   |<---->|  AI Core Logic       |<---->|  Language Model     |
| (Escalation)    |      | (Orchestrator)       |      |  (Mixtral)          |
|                 |      |                      |      |                     |
+-----------------+      +----------+-----------+      +---------------------+
       ^                           |                             ^
       |                           v                             |
+-----------------+      +----------+-----------+      +---------------------+
|                 |      |                      |      |                     |
|   Databases     |<---->| Text-to-Speech       |<---->|  Vector Database    |
| (Postgres)      |      | (Coqui TTS)          |      |  (Qdrant)           |
|                 |      |                      |      |                     |
+-----------------+      +----------------------+      +---------------------+
       ^
       |
+-----------------+
|                 |
|  External APIs  |
| (Billing, etc.) |
|                 |
+-----------------+
```

## 2. Detailed Component Breakdown

| Component              | Technology                | Role                                                                                             |
| ---------------------- | ------------------------- | ------------------------------------------------------------------------------------------------ |
| **Call Handling**      | **Asterisk PBX**          | Receives inbound SIP calls, manages audio streams (RTP), and handles call control (transfer, hangup). |
| **AI Voice Gateway**   | **Python (FastAPI)**      | Bridges Asterisk and AI services. Uses ARI/AGI for call control and WebSockets for audio streaming. |
| **Speech-to-Text**     | **Whisper (Streaming)**   | Transcribes the caller's speech into text in real-time.                                          |
| **AI Core Logic**      | **Python**                | Orchestrates the AI workflow: intent recognition, sentiment analysis, data retrieval, and response generation. |
| **Language Model**     | **Mixtral 8x7B**          | Understands user intent, generates human-like responses, and performs tool-calling to interact with APIs. |
| **Text-to-Speech**     | **Coqui TTS**             | Converts the LLM's text response into natural, emotionally expressive audio.                         |
| **Vector Database**    | **Qdrant**                | Stores embeddings of past conversations and knowledge base articles for efficient retrieval (RAG).      |
| **Customer Database**  | **PostgreSQL**            | Stores customer profiles, call logs, and other structured data.                                    |
| **External APIs**      | **REST (Mocked)**         | Provides access to billing, complaint, and network status information.                             |
| **Message Queue**      | **RabbitMQ**              | Decouples services and manages asynchronous tasks like post-call processing.                       |
| **Cache**              | **Redis**                 | Caches frequently accessed data to reduce latency.                                               |

## 3. Call Flow Diagram

1.  **Incoming Call:** A customer calls the telecom's support number. The call lands on the Asterisk PBX.
2.  **Routing to AI:** Asterisk's dialplan executes an AGI/ARI script, routing the call to the AI Voice Gateway.
3.  **Audio Streaming:** The Gateway establishes a WebSocket connection and starts receiving the audio stream (RTP) from Asterisk.
4.  **Real-time Transcription:** The audio stream is forwarded to the Whisper STT service, which converts speech to text in real-time.
5.  **Intent Analysis:** The transcribed text is sent to the AI Core Logic, which uses the Mixtral LLM to determine the caller's intent (e.g., "billing query," "network complaint") and sentiment.
6.  **Data Retrieval (RAG):** The Core Logic queries the Qdrant vector database for relevant information from past conversations or knowledge base articles. It also queries the PostgreSQL database and external APIs for customer-specific data.
7.  **Response Generation:** The retrieved information is combined with the user's query and fed into the Mixtral LLM to generate a contextual and accurate response.
8.  **Speech Synthesis:** The LLM's text response is sent to the Coqui TTS service, which generates audio with the appropriate emotional tone (e.g., empathetic for a complaint, cheerful for a query).
9.  **Audio Playback:** The generated audio is streamed back to the AI Voice Gateway and played to the caller via Asterisk.
10. **Human Escalation:** If the AI's confidence is low, the caller's sentiment is highly negative, or the caller explicitly asks for a human, the Core Logic instructs the Gateway to transfer the call to a human agent queue in Asterisk.
11. **Post-Call Processing:** After the call ends, the transcript and a summary are stored in the PostgreSQL database. This data is used to update the Qdrant vector database for continuous learning.

## 4. Tech Stack Justification

*   **Asterisk:** The de-facto open-source standard for PBX systems, with robust support for SIP, RTP, and external control via ARI/AGI.
*   **Python (FastAPI):** Ideal for the AI Voice Gateway due to its high performance, asynchronous capabilities, and rich ecosystem of AI/ML libraries.
*   **Whisper:** State-of-the-art open-source STT model from OpenAI, offering high accuracy. Streaming implementations are available for real-time applications.
*   **Mixtral 8x7B:** A powerful open-source Mixture of Experts (MoE) model that provides excellent performance and is capable of tool-calling.
*   **Coqui TTS:** A leading open-source TTS engine with a wide variety of high-quality voices and support for emotional expression.
*   **Qdrant:** A fast and scalable open-source vector database, perfect for RAG-based applications.
*   **PostgreSQL:** A reliable and feature-rich open-source relational database.
*   **RabbitMQ & Redis:** Industry-standard open-source tools for building scalable and resilient distributed systems.

## 5. Docker Architecture

```yaml
# docker-compose.yml
version: '3.8'

services:
  asterisk:
    image: asterisk:20 # Pinned version for production
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
    volumes:
      - ./asterisk/config:/etc/asterisk

  ai-voice-gateway:
    build: ./ai-voice-gateway
    ports:
      - "8000:8000"
    depends_on:
      - rabbitmq
      - redis

  stt-service:
    build: ./stt-service
    # GPU support is recommended
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  llm-service:
    build: ./llm-service
    # GPU is highly recommended
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  tts-service:
    build: ./tts-service
    # GPU is recommended
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  qdrant:
    image: qdrant/qdrant:v1.7.4 # Pinned version for production
    ports:
      - "6333:6333"
    volumes:
      - ./qdrant_storage:/qdrant/storage

  postgres:
    image: postgres:13-alpine # Pinned version for production
    environment:
      POSTGRES_DB: call_center
      POSTGRES_USER: ${POSTGRES_USER:-user} # Use environment variables for credentials
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-password} # Use environment variables for credentials
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  rabbitmq:
    image: rabbitmq:3-management-alpine # Pinned version for production
    ports:
      - "5672:5672"
      - "15672:15672"

  redis:
    image: redis:6-alpine # Pinned version for production
    ports:
      - "6379:6379"

volumes:
  postgres_data:
  qdrant_storage:
```

## 6. Sample Asterisk Configs

**`pjsip.conf`**

```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0

[my-trunk-endpoint]
type=endpoint
context=from-external
disallow=all
allow=ulaw
aors=my-trunk-aor

[my-trunk-aor]
type=aor
max_contacts=1
```

**`extensions.conf`**

```ini
[from-external]
exten => _X.,1,NoOp(Incoming call from ${CALLERID(num)})
 same => n,Answer()
 same => n,Stasis(ai-call-center)
 same => n,Hangup()

[human-agent-queue]
exten => 9000,1,NoOp(Transferring to human agent queue)
 same => n,Queue(support_queue)
 same => n,Hangup()
```

## 7. API Schemas (OpenAPI 3.0)

```yaml
openapi: 3.0.0
info:
  title: Telecom Customer APIs
  version: 1.0.0

paths:
  /billing/{customer_id}:
    get:
      summary: Get billing information
      parameters:
        - name: customer_id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Billing details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BillingInfo'

  /complaints/{customer_id}:
    get:
      summary: Get complaint history
      # ... (similar structure)

components:
  schemas:
    BillingInfo:
      type: object
      properties:
        customerId:
          type: string
        currentBalance:
          type: number
        dueDate:
          type: string
          format: date
```

## 8. Code Snippets / Pseudocode

**AI Voice Gateway (main.py using FastAPI)**

```python
from fastapi import FastAPI, WebSocket
import asyncio
import asterisk.ari

app = FastAPI()

@app.websocket("/ws/{call_id}")
async def websocket_endpoint(websocket: WebSocket, call_id: str):
    await websocket.accept()
    # Stream audio to STT service and receive audio from TTS service

@app.on_event("startup")
async def startup_event():
    # Connect to Asterisk ARI using credentials from environment variables
    client = await asterisk.ari.connect(
        'http://asterisk:8088/',
        os.getenv('ARI_USER'),
        os.getenv('ARI_PASSWORD')
    )

    async def on_stasis_start(channel, event):
        # Answer the call and start the AI interaction loop
        await channel.answer()
        # ...

    client.on_channel_event('StasisStart', on_stasis_start)
```

**RAG Logic**

```python
def get_contextual_info(query_text, customer_id):
    # 1. Embed the query
    query_embedding = embedding_model.embed(query_text)

    # 2. Search vector DB
    search_results = qdrant_client.search(
        collection_name="conversations",
        query_vector=query_embedding,
        limit=3
    )

    # 3. Retrieve customer data
    customer_data = postgres_client.get_customer(customer_id)

    # 4. Format context for LLM
    context = " ".join([res.payload['text'] for res in search_results])
    context += f" Customer Info: {customer_data}"
    return context
```

## 9. Learning Pipeline

1.  **Post-Call:** A "call ended" event triggers a message to a RabbitMQ queue.
2.  **Processing Worker:** A Python worker consumes the message, retrieves the full transcript and metadata from PostgreSQL.
3.  **Summarization:** The worker uses the Mixtral LLM to summarize the conversation and extract key entities and outcomes.
4.  **Knowledge Extraction:** It identifies any new, useful information that could benefit future calls (e.g., a solution to a new problem).
5.  **Embedding & Storage:** The extracted knowledge is broken down into chunks, converted into embeddings, and stored in the Qdrant vector database.

## 10. Human Escalation Logic

A call is transferred to the `human-agent-queue` if any of the following conditions are met:

*   **Sentiment Analysis:** A real-time sentiment analysis model scores the user's frustration level above a certain threshold (e.g., > 0.8 on a scale of 0 to 1).
*   **Low Confidence:** The LLM's response generation has a confidence score below a predefined threshold (e.g., < 0.7).
*   **Explicit Request:** The user says keywords like "human," "agent," "manager," or "speak to a person."
*   **Repetition:** The system detects that it's in a loop, answering the same question multiple times without progress.

## 11. Cost Optimization

*   **Model Quantization:** Use 4-bit quantized versions of Mixtral and Whisper to significantly reduce VRAM requirements and allow deployment on more affordable GPUs.
*   **Hardware Profiling:** Profile each AI service to determine the optimal CPU/GPU allocation. Not all services may require a high-end GPU.
*   **Batching:** For STT and TTS services, implement request batching to improve GPU utilization during high-traffic periods.
*   **Voice Activity Detection (VAD):** Use VAD to avoid sending silence to the STT service, reducing unnecessary processing.

## 12. Production Hardening Notes

*   **Security:**
    *   Store all secrets (API keys, passwords) in a secure vault (e.g., HashiCorp Vault).
    *   Implement network policies in Docker to restrict communication between services.
    *   Use PII masking libraries to redact sensitive information before logging or storing transcripts.
*   **Monitoring:**
    *   Deploy Prometheus and Grafana to monitor system metrics (CPU, memory, GPU utilization, call volume, latency).
    *   Implement structured logging (e.g., JSON format) for all services and centralize them in a logging solution like the ELK stack.
*   **Testing:**
    *   Perform load testing using tools like `sipp` to simulate high call volumes and identify performance bottlenecks.
    *   Create a comprehensive suite of integration tests to ensure all components work together correctly.
*   **Resilience:**
    *   Configure health checks in Docker Compose to automatically restart failing services.
    *   Implement a robust backup and recovery strategy for PostgreSQL and Qdrant data.

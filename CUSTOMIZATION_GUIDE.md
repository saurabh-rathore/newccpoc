# Customization Guide: Adapting the Knowledge Base

This guide explains how to customize the AI's knowledge base to fit your specific business domain, such as healthcare, finance, or e-commerce.

## How the AI Accesses Knowledge: Retrieval-Augmented Generation (RAG)

The AI in this system is not a generic chatbot. It uses a powerful technique called **Retrieval-Augmented Generation (RAG)** to provide accurate, context-aware answers.

Here is the process:
1.  A user asks a question (e.g., "What are your business hours?").
2.  The system converts this question into a mathematical representation (an embedding).
3.  It then searches the **Qdrant vector database** for documents or facts that are mathematically similar to the question.
4.  The most relevant information it finds is retrieved and added to the AI's "context."
5.  Finally, the AI is given the original question *and* the retrieved context and is instructed to formulate an answer based on the provided information.

This means the AI's knowledge is **not** in the model itself, but in the data you provide to the Qdrant database. To change what the AI knows, you simply change the data in the database.

## How to Customize the Knowledge Base

The knowledge base is currently populated with a small set of dummy telecom data for demonstration purposes. To adapt the system for your needs, you need to replace this with your own data.

The relevant code is located in the **Language Model service**:
*   **File:** `llm-service/main.py`

Inside this file, you will find a section under the comment `# --- Qdrant Setup ---`. The code block below it is responsible for populating the database.

### Original Telecom Example (from `llm-service/main.py`):

```python
# --- Qdrant Setup (only if not in CPU mode) ---
if DEVICE != "cpu":
    try:
        # ... (code to create the collection) ...

        logger.info("Uploading dummy knowledge base data to Qdrant...")
        qdrant_client.upsert(
            collection_name=QDRANT_COLLECTION,
            points=[
                # This is the dummy data you need to replace
                models.PointStruct(id=1, vector=embedding_model.encode("Your bill is due on the 25th of each month.").tolist(), payload={"text": "The billing cycle ends and payment is due on the 25th of every month."}),
                models.PointStruct(id=2, vector=embedding_model.encode("How do I reset my password?").tolist(), payload={"text": "You can reset your account password by visiting our website and clicking the 'Forgot Password' link."}),
                models.PointStruct(id=3, vector=embedding_model.encode("What are the international calling rates?").tolist(), payload={"text": "International calling rates vary by country. For specific rates, please say the country you wish to call. If the user asks for a transfer, respond with 'transfer to human'."}),
            ],
            wait=True
        )
    except Exception as e:
        logger.warning(f"Failed to set up Qdrant collection: {e}")
```

### Healthcare / Patient Details Example

To adapt this for a healthcare context, you would simply replace the `PointStruct` objects with your own information. The `id` should be a unique integer, the `vector` is the embedding of a likely user query, and the `payload` contains the actual answer or information you want the AI to use.

Here is how you would modify the file to use healthcare data instead:

```python
# --- Qdrant Setup (only if not in CPU mode) ---
if DEVICE != "cpu":
    try:
        # ... (code to create the collection) ...

        logger.info("Uploading dummy healthcare knowledge base data to Qdrant...")
        qdrant_client.upsert(
            collection_name=QDRANT_COLLECTION,
            points=[
                # --- REPLACE THE OLD DATA WITH THIS NEW DATA ---
                models.PointStruct(id=1,
                                   vector=embedding_model.encode("What are the visiting hours for cardiology?").tolist(),
                                   payload={"text": "The visiting hours for the cardiology department are from 11 AM to 8 PM daily."}),

                models.PointStruct(id=2,
                                   vector=embedding_model.encode("How do I schedule an appointment?").tolist(),
                                   payload={"text": "You can schedule an appointment by speaking to our scheduling department. Say 'transfer me to scheduling' to be connected."}),

                models.PointStruct(id=3,
                                   vector=embedding_model.encode("What do I need to do before my surgery?").tolist(),
                                   payload={"text": "For pre-operative instructions, you must not eat or drink anything after midnight the day before your surgery. Please arrange for someone to drive you home."}),

                models.PointStruct(id=4,
                                   vector=embedding_model.encode("Where is the hospital located?").tolist(),
                                   payload={"text": "The main hospital campus is located at 123 Health St. The parking garage is on the corner of Health and Wellness Ave."})
            ],
            wait=True
        )
    except Exception as e:
        logger.warning(f"Failed to set up Qdrant collection: {e}")
```

### Important Next Steps

1.  **Modify the File:** Edit `llm-service/main.py` with your own data.
2.  **Rebuild the Image:** Because you have changed the source code, you must rebuild the Docker image for the LLM service.
    *   If using the single-node `docker-compose` setup, run: `./run.sh build`
    *   If using the Kubernetes setup, re-run the `deploy-on-prem.sh` or `deploy-eks.sh` script, which will handle the rebuild and redeployment.

This process allows you to tailor the AI's knowledge to any domain, making the system highly flexible.

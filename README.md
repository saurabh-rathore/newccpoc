# AI-Powered Voice Call Center

This project provides a complete, production-ready, fully autonomous AI-powered voice call center solution for a telecom company. It is built entirely with open-source tools and is designed to be deployed on-premise or in a private cloud using Docker and Kubernetes.

## System Overview

The system is designed to handle a high volume of concurrent calls, integrating directly with an Asterisk PBX. It leverages a suite of modern AI components to understand customer intent, retrieve relevant data, and provide natural, emotionally expressive responses.

-   **Asterisk Integration**: Receives inbound calls from Asterisk via the Asterisk REST Interface (ARI).
-   **Speech-to-Text**: Converts the caller's speech into text in real-time.
-   **Natural Language Understanding**: An LLM analyzes the text to determine intent and sentiment.
-   **RAG Pipeline**: Retrieves information from a vector database (previous conversations, knowledge base) and customer data from APIs/DBs to form a comprehensive context.
-   **Response Generation**: The LLM generates a context-aware and natural response.
-   **Text-to-Speech**: Converts the generated text back into a human-like voice with emotional nuance.
-   **Continuous Learning**: All conversations are stored, summarized, and fed back into the knowledge base to continuously improve the system.
-   **Human Escalation**: Seamlessly transfers calls to a human agent queue in Asterisk if the AI cannot resolve the issue.

## Architecture

The system is built on a microservices architecture, with each component running in its own Docker container. This ensures scalability, resilience, and maintainability.

-   **AI Voice Gateway**: The central service that communicates with Asterisk, manages the call flow, and orchestrates the other AI services.
-   **STT Service**: A dedicated Speech-to-Text service (e.g., Whisper).
-   **LLM Service**: Hosts the core Large Language Model (e.g., Llama 3, Mistral) for NLU and response generation.
-   **TTS Service**: A dedicated Text-to-Speech service (e.g., Piper) for generating audio.
-   **Vector Database**: A ChromaDB instance for storing and retrieving conversational history and knowledge base articles.
-   **Databases & Caches**: PostgreSQL for customer data and Redis for caching and message queuing.

---

## Deployment Options

This project offers multiple ways to deploy the services, from a simple audio file tester to a full production-ready Kubernetes setup.

### 1. Simple Audio File Testing (Recommended First Step)

This is the easiest way to test the core AI pipeline (STT -> LLM -> TTS) without the complexity of a real-time phone call. You provide an audio file and get an audio file back.

For detailed instructions, please see the guide in the testing directory:
**[-> Read the Audio File Testing Guide <-](./audio-file-tester/TESTING_GUIDE.md)**

---

### 2. Full System Testing with Telephony (Docker Compose)

Once you have verified the AI pipeline with the audio file test, you can proceed to a full, end-to-end test with a live phone call. This method runs the entire system, including Asterisk, using Docker Compose.

### Prerequisites

-   A machine with Docker and the Docker Compose plugin (V2) installed.
-   A SIP client (e.g., Zoiper, Linphone) to make a call.

### One-Click Deployment

```bash
# Make the script executable
chmod +x deploy-telephony.sh

# Run the script
./deploy-telephony.sh
```

After the script finishes, all services will be running in the background. You can connect your SIP client to your machine's IP address on port 5060 and dial extension `1000` to speak with the AI.

---

### 3. Bare-Metal Deployment (No Containers)

This method installs all software and services directly onto the host machine without using Docker or Kubernetes. This is a straightforward alternative for environments where containerization is not desired.

### Prerequisites

-   An Ubuntu 22.04 server.
-   Root (sudo) access.

### One-Click Deployment

This single script will install, configure, and set up all components as background services.

```bash
# Make the script executable
chmod +x deploy-bare-metal.sh

# Run the script with sudo
sudo ./deploy-bare-metal.sh
```

After the script completes, all AI services will be enabled to start on boot and can be managed using `systemctl` (e.g., `sudo systemctl status ai-voice-gateway`).

---

## Production Deployment (Single-Node Kubernetes)

This is the recommended method for a production-ready, on-premise deployment. It provides the most resilience and scalability.

### Prerequisites

-   An Ubuntu 22.04 server (or VM) with at least 8GB RAM, 4 CPU cores, and 50GB of disk space.
-   Root access to the server.
-   A stable internet connection.

### One-Click Deployment

For a fully automated setup, simply run the master deployment script. This will execute all necessary steps, from setting up the host environment to deploying the application on Kubernetes.

```bash
# Make the script executable
chmod +x deploy-all-on-prem-cpu.sh

# Run as root
sudo ./deploy-all-on-prem-cpu.sh
```

### Manual Step-by-Step Deployment

If you prefer to run each stage manually or need to debug a specific step, you can execute the scripts in the `on-prem-deployment/` directory in the following order. **All scripts must be run as root.**

```bash
# Navigate to the deployment scripts directory
cd on-prem-deployment

# Step 1: Prepare the host machine (install Docker, disable swap, etc.)
./01-setup-host.sh

# Step 2: Set up the Kubernetes cluster using kubeadm
./02-setup-kubernetes-cluster.sh

# Step 3: Install cluster add-ons (Networking, Load Balancer, Registry)
./03-setup-onprem-components.sh

# Step 4: Build the application Docker images and deploy them to Kubernetes
./04-build-and-deploy-app.sh
```

After the deployment is complete, you can monitor the status of the pods:
```bash
kubectl get pods -n ai-call-center -w
```

---
## Asterisk Integration

To connect this system to Asterisk, you will need to configure your `extensions.conf` dialplan to route incoming calls to the `ai-voice-gateway` service.

**Example `extensions.conf`:**
```ini
[from-internal]
exten => 1000,1,NoOp(New call to AI Call Center)
  same => n,Answer()
  ; Send the call to the Stasis (ARI) application named 'ai-voice-gateway'
  same => n,Stasis(ai-voice-gateway)
  same => n,Hangup()
```

When using the Docker Compose testing deployment, Asterisk is already containerized and networked. You can connect your SIP client directly to the host machine's IP address on port 5060.

---

## Troubleshooting

### Error: "No space left on device"

After multiple builds or failed deployment attempts, your system can fill up with orphaned Docker images, build caches, and unused data volumes.

To clean up your system and reclaim disk space, a comprehensive cleanup script is provided.

**WARNING:** This script is destructive and will remove all stopped Docker containers and unused images.

```bash
# Make the script executable
chmod +x cleanup-all.sh

# Run the script with sudo
sudo ./cleanup-all.sh
```
This will aggressively prune your Docker system, clear package manager caches, and give you the option to remove any services installed by the bare-metal deployment.

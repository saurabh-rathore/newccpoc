# Local Testing Guide

This guide provides a comprehensive walkthrough for testing your AI Voice Call Center deployment. The process involves two stages:
1.  **System Verification:** Confirming that all backend services are running correctly.
2.  **Live Call Test:** Placing a call to the system using a free softphone client.

These steps are applicable to all deployment methods (on-premise Kubernetes, EKS, or the single-node Docker Compose setup).

---

## Stage 1: System Verification

Before placing a call, it's crucial to verify that all the containerized services have started correctly.

### Step 1: Check Pod/Container Status

Connect to your server via SSH and run the appropriate command for your environment:

*   **For Kubernetes Deployments** (`deploy-on-prem.sh` or `deploy-eks.sh`):
    ```bash
    kubectl get pods -n ai-call-center -w
    ```
    You should see a list of all pods. Wait until the `STATUS` for every pod shows **`Running`**. It may take several minutes for the AI services to download the models and start up for the first time.

*   **For the Single-Node Docker Compose Deployment** (`deploy.sh`):
    ```bash
    docker ps
    ```
    You should see a list of all containers with a `STATUS` of **`Up`**.

### Step 2: Check Service Logs for Success Messages

Checking the logs of the key services is the best way to confirm they are ready.

*   **For Kubernetes Deployments:**
    You can check the logs for each service. The most important ones are the AI services.
    ```bash
    # Check the LLM service log (look for "LLM model loaded successfully")
    kubectl logs -n ai-call-center -l app=llm-service -f

    # Check the STT service log (look for "Whisper model loaded successfully")
    kubectl logs -n ai-call-center -l app=stt-service -f

    # Check the AI Voice Gateway log (look for "ARI connected and listeners set up")
    kubectl logs -n ai-call-center -l app=ai-voice-gateway -f
    ```
    *(Press `Ctrl+C` to exit the log view for each service).*

*   **For the Single-Node Docker Compose Deployment:**
    Use the provided helper script to view all logs at once.
    ```bash
    ./run.sh logs
    ```
    Look for the same success messages mentioned above from the `llm-service`, `stt-service`, and `ai-voice-gateway` containers.

Once you have confirmed that all services are running and have successfully loaded their models, you can proceed to the live call test.

---

## Stage 2: Live Call Test

To test the system, you need a "softphone"—a software application that allows you to make internet-based (SIP) calls from your computer.

### Step 1: Find the System's IP Address

You need the IP address of the Asterisk service to configure your softphone.

*   **For Kubernetes Deployments:**
    Run the following command to get the external IP address assigned to the Asterisk load balancer.
    ```bash
    kubectl get service asterisk-loadbalancer -n ai-call-center
    ```
    Look for the value in the `EXTERNAL-IP` column. This is the IP you will use.

*   **For the Single-Node Docker Compose Deployment:**
    The IP address is simply the public IP address of your EC2 instance or Ubuntu server.

### Step 2: Download and Install a Softphone

We recommend **Zoiper**, which is a popular and free softphone client available for Windows, macOS, and Linux.
*   **Download Zoiper 5 Lite (the free version) from:** [https://www.zoiper.com/en/voip-softphone/download/current](https://www.zoiper.com/en/voip-softphone/download/current)

Install and open the application.

### Step 3: Configure the Softphone

Follow these steps to configure Zoiper to connect to your AI Call Center:

1.  When you first open Zoiper, click **"Continue as a Free user."**
2.  You will see a prompt for "Username / Login" and "Password." Enter the following:
    *   **Username / Login:** `testuser@<YOUR_SYSTEM_IP>`
        *(Replace `<YOUR_SYSTEM_IP>` with the IP address you found in Step 1).*
    *   **Password:** You can enter **any password**. The system is configured to allow any credentials for testing.
3.  Click **"Login."**
4.  Zoiper will now try to automatically find the server configuration. It will likely fail. When it does, you will see a field for the **"Domain / Outbound proxy."** Enter your system's IP address here:
    *   **Domain / Outbound proxy:** `<YOUR_SYSTEM_IP>`
5.  Click **"Next."**
6.  The next step, "Authentication and Outbound Proxy," is optional. You can just click **"Skip."**
7.  Zoiper will test for different connection types. It should find the SIP UDP connection. When it does, click **"Next."**
8.  Your account is now configured!

### Step 4: Make the Test Call

1.  In the Zoiper dialpad, enter any number (e.g., `1000`) and click the **"Dial"** button.
2.  The call will be placed to your deployed Asterisk service.
3.  The AI Voice Gateway will answer the call.
4.  You should hear the AI's synthesized voice say: **"Welcome to our automated service. How can I help you today?"**
5.  You can now speak. Ask a question related to the knowledge base you configured (e.g., "What are the visiting hours?").
6.  You should see activity in the service logs as your speech is transcribed, sent to the LLM, and a response is generated and spoken back to you.

If you hear the welcome message and get a response to your question, your deployment and local test were successful!

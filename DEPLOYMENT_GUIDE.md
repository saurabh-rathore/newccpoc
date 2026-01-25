# AI Voice Call Center Deployment Guide

This guide provides step-by-step instructions to deploy the complete AI Voice Call Center solution on a fresh Ubuntu 22.04 server.

The process is automated via a single deployment script, `deploy.sh`, which will install all necessary prerequisites, build the service images, and launch the application stack.

## Prerequisites

Before you begin, ensure you have the following:

1.  **A fresh Ubuntu 22.04 LTS server.**
2.  **An NVIDIA GPU:** The AI models for STT, LLM, and TTS require a CUDA-enabled NVIDIA GPU to run efficiently.
3.  **Root or `sudo` access:** The deployment script needs to install system packages.
4.  **Git:** The `git` command-line tool must be installed to clone the repository.
5.  **An internet connection:** The script will download packages and Docker images.

---

## Deployment Steps

### Step 1: Clone the Repository

First, connect to your Ubuntu server via SSH and clone this repository to your home directory.

```bash
# Install git if it's not already present
sudo apt-get update && sudo apt-get install -y git

# Clone the repository
git clone <repository_url>
cd <repository_directory>
```
*(Replace `<repository_url>` and `<repository_directory>` with the actual URL and folder name).*

### Step 2: Run the Automated Deployment Script

The `deploy.sh` script is designed to automate the entire setup process. It will:
- Install Docker and Docker Compose.
- Install the NVIDIA Container Toolkit to enable GPU access for Docker containers.
- Build the Docker images for all AI services (this will take a while as it also downloads the AI models).
- Create a default `.env` file for configuration.
- Launch the entire application stack using `docker-compose`.

To run the script, execute the following command from the root of the project directory:

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

The script will prompt you to reboot the server after installing the NVIDIA drivers. After rebooting, you will need to `cd` back into the project directory and run `sudo ./deploy.sh` again to complete the Docker builds and launch the services.

### Step 3: Verify the Deployment

After the script finishes, all services should be running in the background. You can verify this by checking the status of the Docker containers.

```bash
# List all running containers
docker ps
```

You should see a list of running containers, including `asterisk`, `mysql`, `qdrant`, `ai-voice-gateway`, `stt-service`, `llm-service`, and `tts-service`.

To view the real-time logs for all services, you can use the included `run.sh` script:

```bash
./run.sh logs
```
*(Press `Ctrl+C` to exit the logs view).*

### Step 4: Place a Test Call

The system is now ready to receive calls. The Asterisk service is listening for SIP calls on port `5060`.

1.  **Configure a SIP Client:** Use a softphone client (like Zoiper, MicroSIP, or Linphone) on your computer.
2.  **Set up the Account:**
    -   **Domain/Server:** The IP address of your Ubuntu server.
    -   **Username/Password:** You can use any credentials, as the Asterisk configuration allows anonymous calls.
3.  **Place the Call:** Dial any number (e.g., "1234") from your SIP client.

The call should be routed to the AI Voice Gateway, and you should hear the welcome message: "Welcome to our automated service. How can I help you today?" You can then speak, and the AI will respond.

---

## Managing the Services

The `run.sh` script provides simple commands to manage the application stack:

-   **Start all services:** `./run.sh start`
-   **Stop all services:** `./run.sh stop`
-   **Restart all services:** `./run.sh restart`
-   **View logs:** `./run.sh logs`
-   **Rebuild service images:** `./run.sh build`

## Customization

To customize the configuration (e.g., database passwords, ARI credentials), you can edit the `.env` file in the project's root directory. After making changes, restart the services for them to take effect:

```bash
nano .env
./run.sh restart
```

#!/bin/bash
set -e

# This script provides a simple, one-click deployment for the full telephony
# system, using Docker Compose.

echo "========================================================================"
echo "Starting Full Telephony Docker Compose Deployment"
echo "========================================================================"

# --- Check for Docker ---
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker before running this script."
    exit 1
fi
if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose (V2) is not available. Please ensure your Docker installation includes the Compose plugin."
    exit 1
fi

# --- Setup .env file ---
if [ ! -f ".env" ]; then
    echo "No .env file found. Copying from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "Successfully created .env file. Please review it before proceeding if needed."
    else
        echo "Error: .env.example not found. Cannot create .env file."
        exit 1
    fi
fi

# --- Generate ARI Client ---
# The ai-voice-gateway needs the ARI client to be generated.
# We will temporarily start Asterisk to do this.
echo "Temporarily starting Asterisk to generate ARI client..."
docker compose -f docker-compose.telephony.yml up -d asterisk
# Wait for Asterisk to be ready
sleep 10
echo "Generating client..."
(cd ai-voice-gateway && bash generate-ari-client.sh)
echo "Shutting down temporary Asterisk..."
docker compose -f docker-compose.telephony.yml down

echo "Starting all services for the full telephony environment..."
# The --build flag ensures images are rebuilt if the source code has changed.
# The --no-cache flag is added to avoid issues with stale builds.
# The -d flag runs the containers in detached mode.
docker compose -f docker-compose.telephony.yml up --build --no-cache -d

echo ""
echo "========================================================================"
echo "Deployment Complete!"
echo "All services for the full telephony system have been started."
echo "You can connect a SIP client to your machine's IP on port 5060 to place a call."
echo ""
echo "You can view the status of the containers by running:"
echo "  docker compose -f docker-compose.telephony.yml ps"
echo "========================================================================"

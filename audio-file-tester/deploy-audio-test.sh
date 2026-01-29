#!/bin/bash
set -e

# This script provides a simple, one-click deployment for the audio file
# testing environment, using Docker Compose without Asterisk.

echo "========================================================================"
echo "Starting Audio File Tester Docker Compose Deployment"
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
# The script expects the .env file to be in the parent directory
ENV_FILE="../.env"
ENV_EXAMPLE_FILE="../.env.example"

if [ ! -f "$ENV_FILE" ]; then
    echo "No .env file found in the root directory. Copying from .env.example..."
    if [ -f "$ENV_EXAMPLE_FILE" ]; then
        cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
        echo "Successfully created .env file in the root directory. Please review it if needed."
    else
        echo "Error: .env.example not found in the root directory. Cannot create .env file."
        exit 1
    fi
fi

echo "Starting all services for the audio test environment..."
# The --build flag ensures images are rebuilt if the source code has changed.
# The -d flag runs the containers in detached mode.
docker compose -f docker-compose.audio-test.yml --env-file "$ENV_FILE" up --build -d

echo ""
echo "========================================================================"
echo "Deployment Complete!"
echo "All services for the audio file tester have been started."
echo "The Audio Gateway API is available on port 8000."
echo ""
echo "You can view the status of the containers by running:"
echo "  docker compose -f docker-compose.audio-test.yml ps"
echo ""
echo "To test, send a POST request with an audio file to:"
echo "  http://localhost:8000/process-voice-note"
echo "========================================================================"

#!/bin/bash
set -e

# This script provides a simple, one-click deployment for testing purposes,
# using Docker Compose without Kubernetes.

echo "========================================================================"
echo "Starting Non-Kubernetes Docker Compose Deployment for Testing"
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

echo "Starting all services via Docker Compose..."
# The --build flag ensures images are rebuilt if the source code has changed.
# The --no-cache flag ensures we use the latest Dockerfile changes.
# The -d flag runs the containers in detached mode.
docker compose -f docker-compose.testing.yml up --build --no-cache -d

echo ""
echo "========================================================================"
echo "Deployment Complete!"
echo "All services have been started in the background."
echo "You can view the status of the containers by running:"
echo "  docker compose -f docker-compose.testing.yml ps"
echo ""
echo "To view the logs of a specific service, run:"
echo "  docker compose -f docker-compose.testing.yml logs -f <service_name>"
echo "(e.g., docker compose -f docker-compose.testing.yml logs -f ai-voice-gateway)"
echo "========================================================================"

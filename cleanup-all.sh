#!/bin/bash
set -e

echo "========================================================================"
echo "Comprehensive Cleanup Script"
echo "========================================================================"
echo "This script will aggressively remove Docker artifacts, clear package"
echo "caches, and uninstall bare-metal services to free up disk space."
echo "WARNING: This is a destructive operation and will remove ALL Docker"
echo "         containers, images, and volumes not currently in use."
echo "========================================================================"
echo ""

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

echo "--- Step 1: Cleaning Docker System ---"
if command -v docker &> /dev/null; then
    echo "Stopping all running containers..."
    # Stop all running containers to ensure a clean prune
    docker stop $(docker ps -a -q) || true

    echo "Running 'docker system prune -a -f'..."
    echo "This will remove all stopped containers, all networks not used by at least one container, all dangling images, and all build cache."
    docker system prune -a -f

    echo "Removing Docker volumes..."
    # The prune command doesn't always get named volumes. We remove ours explicitly.
    docker volume rm app_postgres_data audio-file-tester_postgres_data || true
    docker volume rm app_qdrant_data audio-file-tester_qdrant_data || true
    echo "Docker cleanup complete."
else
    echo "Docker not found. Skipping Docker cleanup."
fi
echo ""

echo "--- Step 2: Clearing APT Package Cache ---"
echo "Running 'apt-get clean'..."
apt-get clean
echo "APT cache cleared."
echo ""

echo "--- Step 3: Removing Generated Files ---"
# Get the absolute path of the script's directory (project root)
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ARI_CLIENT_DIR="$SCRIPT_DIR/ai-voice-gateway/ari_client"

if [ -d "$ARI_CLIENT_DIR" ]; then
    echo "Removing generated ARI client at $ARI_CLIENT_DIR..."
    rm -rf "$ARI_CLIENT_DIR"
fi

# Remove any downloaded models that may be in /models
if [ -d "/models" ]; then
    echo "Removing downloaded models from /models..."
    rm -rf /models
fi
echo "Generated file cleanup complete."
echo ""

echo "--- Step 4: Removing Bare-Metal Services (Optional) ---"
echo "The following section will disable and remove the systemd services"
echo "created by the bare-metal deployment script."
read -p "Do you want to proceed with removing bare-metal services? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SERVICES=("ai-voice-gateway" "llm-service" "stt-service" "tts-service")
    for service in "${SERVICES[@]}"; do
        SERVICE_FILE="/etc/systemd/system/${service}.service"
        if [ -f "$SERVICE_FILE" ]; then
            echo "Stopping and disabling $service.service..."
            systemctl stop "$service.service" || true
            systemctl disable "$service.service" || true
            rm "$SERVICE_FILE"
            echo "Removed $SERVICE_FILE."
        else
            echo "$service.service not found. Skipping."
        fi
    done
    echo "Reloading systemd daemon..."
    systemctl daemon-reload
    echo "Bare-metal services have been removed."
else
    echo "Skipping removal of bare-metal services."
fi
echo ""

echo "========================================================================"
echo "Cleanup complete."
echo "The system should now have significantly more free disk space."
echo "========================================================================"

#!/bin/bash
set -e

echo "========================================================================"
echo "Step 4: Setting Up AI Services to Run in the Background (systemd)"
echo "========================================================================"
echo "This script will create and enable systemd services for each AI"
echo "microservice, allowing them to run persistently in the background."
echo "========================================================================"

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Get the absolute path of the script's directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory (the project root)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
TEMPLATE_FILE="$SCRIPT_DIR/service-template.service"

# --- IMPORTANT: User Configuration ---
# The services need to run as a non-root user.
# We are assuming the user is 'ubuntu'. If you are using a different
# username (like 'admin' or your own), please change the variable below.
RUN_AS_USER="ubuntu"

# Verify the user exists
if ! id -u "$RUN_AS_USER" >/dev/null 2>&1; then
    echo "Error: The user '$RUN_AS_USER' does not exist."
    echo "Please edit this script and change the 'RUN_AS_USER' variable to your non-root username."
    exit 1
fi

# Define the services and their ports
declare -A SERVICES
SERVICES=(
    ["ai-voice-gateway"]="8000"
    ["llm-service"]="8002"
    ["stt-service"]="8001"
    ["tts-service"]="8003"
)

for service_name in "${!SERVICES[@]}"; do
    port=${SERVICES[$service_name]}
    echo ""
    echo "--- Creating systemd service for: $service_name ---"

    SERVICE_FILE_PATH="/etc/systemd/system/${service_name}.service"

    # Replace placeholders in the template and create the final service file
    sed -e "s/%i/$service_name/g" \
        -e "s|/path/to/project|$PROJECT_ROOT|g" \
        -e "s/%p/$port/g" \
        -e "s/User=ubuntu/User=$RUN_AS_USER/g" \
        -e "s/Group=ubuntu/Group=$RUN_AS_USER/g" \
        "$TEMPLATE_FILE" > "$SERVICE_FILE_PATH"

    echo "Created service file at $SERVICE_FILE_PATH"
done

# Reload the systemd daemon to recognize the new services
echo ""
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling services to start on boot..."
for service_name in "${!SERVICES[@]}"; do
    systemctl enable "$service_name.service"
done

echo ""
echo "You can now start the services by running:"
for service_name in "${!SERVICES[@]}"; do
    echo "  sudo systemctl start $service_name.service"
done
echo ""
echo "Or by rebooting the machine."
echo ""
echo "========================================================================"
echo "systemd service setup complete."
echo "========================================================================"

#!/bin/bash
set -e

echo "========================================================================"
echo "Step 2: Setting Up Python Virtual Environments and Dependencies"
echo "========================================================================"
echo "This script will create a dedicated Python virtual environment for each"
echo "AI service and install its required packages."
echo "========================================================================"

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# An array of service directories
SERVICES=("ai-voice-gateway" "llm-service" "stt-service" "tts-service")

# Get the absolute path of the script's directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Get the parent directory (the project root)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

for service in "${SERVICES[@]}"; do
    echo ""
    echo "--- Setting up service: $service ---"

    SERVICE_DIR="$PROJECT_ROOT/$service"
    VENV_DIR="$SERVICE_DIR/.venv"

    if [ ! -d "$SERVICE_DIR" ]; then
        echo "Error: Directory for service '$service' not found at '$SERVICE_DIR'."
        exit 1
    fi

    # Create the virtual environment
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
    else
        echo "Virtual environment already exists. Skipping creation."
    fi

    # Special step for the voice gateway: generate the ARI client
    if [ "$service" == "ai-voice-gateway" ]; {
        echo "Generating ARI client for the voice gateway..."
        # We need a running Asterisk to generate the client.
        # Let's check if the Asterisk service is active on the host.
        if ! systemctl is-active --quiet asterisk; then
            echo "Warning: Asterisk service is not running. Attempting to start it..."
            systemctl start asterisk
            # Wait a few seconds for it to initialize
            sleep 5
            if ! systemctl is-active --quiet asterisk; then
                echo "Error: Failed to start Asterisk. Cannot generate ARI client."
                echo "Please ensure Asterisk is installed and can be run via 'systemctl start asterisk'."
                exit 1
            fi
        fi

        # Install dependencies first, which now includes the generator
        if [ -f "$SERVICE_DIR/requirements.txt" ]; then
            echo "Installing Python dependencies from requirements.txt..."
            "$VENV_DIR/bin/pip" install --upgrade pip
            "$VENV_DIR/bin/pip" install -r "$SERVICE_DIR/requirements.txt"
        else
            echo "Warning: requirements.txt not found for service '$service'. Skipping dependency installation."
            # Continue to the next service in the loop
            continue
        fi

        echo "Generating ARI client for the voice gateway..."
        # We need a running Asterisk to generate the client.
        if ! systemctl is-active --quiet asterisk; then
            echo "Warning: Asterisk service is not running. Attempting to start it..."
            systemctl start asterisk
            sleep 5 # Give it a moment to initialize
            if ! systemctl is-active --quiet asterisk; then
                echo "Error: Failed to start Asterisk. Cannot generate ARI client."
                exit 1
            fi
        fi

        # Run the generation script from within the service directory, using the venv's bash
        (cd "$SERVICE_DIR" && "$VENV_DIR/bin/bash" ./generate-ari-client.sh)

        # No need to run pip install again, it was done above
        continue # Skip the generic pip install below
    }

    # Install dependencies for other services
    if [ -f "$SERVICE_DIR/requirements.txt" ]; then
        echo "Installing Python dependencies from requirements.txt..."
        "$VENV_DIR/bin/pip" install --upgrade pip
        "$VENV_DIR/bin/pip" install -r "$SERVICE_DIR/requirements.txt"
    else
        echo "Warning: requirements.txt not found for service '$service'. Skipping dependency installation."
    fi

    echo "--- Finished setup for service: $service ---"
done

echo ""
echo "========================================================================"
echo "All Python environments are set up."
echo "========================================================================"

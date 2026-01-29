#!/bin/bash
set -e

# This master script runs all the individual bare-metal deployment scripts
# in the correct order. It provides a "one-click" deployment experience.

echo "========================================================================"
echo "Starting the Full Bare-Metal (Non-Containerized) Deployment..."
echo "========================================================================"
echo "This script will install and configure all necessary software directly"
echo "on this machine. It will ask for your password for 'sudo' access."
echo "========================================================================"
echo ""

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo (e.g., 'sudo ./deploy-bare-metal.sh')."
    exit 1
fi

# Get the absolute path of the script's directory (project root)
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BM_SCRIPT_DIR="$SCRIPT_DIR/bare-metal-deployment"

# Make all scripts in the deployment directory executable
chmod +x "$BM_SCRIPT_DIR"/*.sh

# Execute each script in order
"$BM_SCRIPT_DIR/01-install-system-deps.sh"
"$BM_SCRIPT_DIR/02-setup-python-env.sh"
"$BM_SCRIPT_DIR/03-configure-services.sh"
"$BM_SCRIPT_DIR/04-setup-systemd-services.sh"

echo ""
echo "========================================================================"
echo "All deployment steps completed successfully!"
echo "The system services have been enabled and can be started."
echo ""
echo "To start the AI services, you can either reboot the machine or run:"
echo "  sudo systemctl start ai-voice-gateway.service"
echo "  sudo systemctl start llm-service.service"
echo "  sudo systemctl start stt-service.service"
echo "  sudo systemctl start tts-service.service"
echo ""
echo "You can check the status of any service with:"
echo "  sudo systemctl status ai-voice-gateway.service"
echo "========================================================================"

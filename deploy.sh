#!/bin/bash

# ==============================================================================
# AI Voice Call Center - Automated Deployment Script for Ubuntu 22.04
# ==============================================================================
# This script automates the setup of all necessary prerequisites and launches
# the application stack. It is designed to be run with sudo privileges.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper Functions ---
function check_command() {
    command -v "$1" >/dev/null 2>&1
}

function print_header() {
    echo ""
    echo "=============================================================================="
    echo " $1"
    echo "=============================================================================="
}

function wait_for_apt_lock() {
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
       echo "Waiting for other package manager processes (like unattended-upgrades) to finish..."
       sleep 5
    done
}

# --- Main Logic ---

# Step 1: Install NVIDIA Drivers and Toolkit
if ! check_command nvidia-smi; then
    print_header "Installing NVIDIA Drivers and Container Toolkit"

    wait_for_apt_lock
    # Add NVIDIA package repositories
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    wait_for_apt_lock
    sudo apt-get update

    wait_for_apt_lock
    sudo apt-get install -y cuda-drivers

    wait_for_apt_lock
    sudo apt-get install -y nvidia-container-toolkit

    print_header "NVIDIA Drivers Installed. A reboot is required."
    echo "Please reboot your system and then run this script again to continue."
    exit 0
else
    echo "NVIDIA drivers are already installed. Skipping."
fi

# Step 2: Install Docker and Docker Compose
if ! check_command docker; then
    print_header "Installing Docker Engine"
    wait_for_apt_lock
    sudo apt-get update
    wait_for_apt_lock
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    wait_for_apt_lock
    sudo apt-get update

    wait_for_apt_lock
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
else
    echo "Docker is already installed. Skipping."
fi

if ! check_command docker-compose; then
    print_header "Installing Docker Compose"
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose is already installed. Skipping."
fi

# Step 3: Configure Docker for NVIDIA GPU
print_header "Configuring Docker to use NVIDIA GPUs"
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Step 4: Initial Application Setup
print_header "Setting up application environment"

if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
else
    echo ".env file already exists. Skipping."
fi

# Step 5: Build and Launch Docker Containers
print_header "Building Docker images (this may take a significant amount of time)..."
docker-compose build

print_header "Launching the AI Voice Call Center application stack..."
docker-compose up -d

print_header "Deployment Complete!"
echo "All services have been started in the background."
echo "You can check the status of the containers with the 'docker ps' command."
echo "To view logs, run './run.sh logs'."
echo "Please refer to DEPLOYMENT_GUIDE.md for instructions on how to place a test call."

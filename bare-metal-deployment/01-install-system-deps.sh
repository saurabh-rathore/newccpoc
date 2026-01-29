#!/bin/bash
set -e

echo "========================================================================"
echo "Step 1: Installing System-level Dependencies"
echo "========================================================================"
echo "This script will install Python, PostgreSQL, Redis, Asterisk, and other"
echo "required packages using the 'apt' package manager."
echo "You will likely be prompted for your password for 'sudo'."
echo "========================================================================"

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Update package list ---
echo "Updating package list..."
apt-get update

# --- Install Python and related tools ---
echo "Installing Python and build tools..."
apt-get install -y python3 python3-pip python3-venv build-essential

# --- Install PostgreSQL ---
if ! command_exists psql; then
    echo "Installing PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
else
    echo "PostgreSQL is already installed. Skipping."
fi

# --- Install Redis ---
if ! command_exists redis-server; then
    echo "Installing Redis..."
    apt-get install -y redis-server
else
    echo "Redis is already installed. Skipping."
fi

# --- Install Asterisk ---
# We need to add the Asterisk repository to get a modern version
if ! command_exists asterisk; then
    echo "Installing Asterisk..."
    apt-get install -y wget gnupg2

    # Add the Asterisk repository key
    wget -O - http://downloads.asterisk.org/pub/telephony/asterisk/keys/pkg.gpg | apt-key add -

    # Add the repository itself
    echo "deb http://downloads.asterisk.org/pub/telephony/asterisk/debian/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/asterisk.list

    apt-get update
    apt-get install -y asterisk
else
    echo "Asterisk is already installed. Skipping."
fi

echo ""
echo "========================================================================"
echo "System dependency installation complete."
echo "========================================================================"

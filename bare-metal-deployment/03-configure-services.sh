#!/bin/bash
set -e

echo "========================================================================"
echo "Step 3: Configuring System Services (Asterisk & PostgreSQL)"
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
ASTERISK_CONFIG_DIR="$PROJECT_ROOT/asterisk/config"

# --- Configure Asterisk ---
echo "Configuring Asterisk..."

if [ -d "$ASTERISK_CONFIG_DIR" ]; then
    # Stop Asterisk to safely replace config files
    if systemctl is-active --quiet asterisk; then
        echo "Stopping Asterisk to apply new configuration..."
        systemctl stop asterisk
    fi

    echo "Copying configuration files to /etc/asterisk/..."
    cp "$ASTERISK_CONFIG_DIR/ari.conf" /etc/asterisk/
    cp "$ASTERISK_CONFIG_DIR/extensions.conf" /etc/asterisk/
    cp "$ASTERISK_CONFIG_DIR/pjsip.conf" /etc/asterisk/
    cp "$ASTERISK_CONFIG_DIR/queues.conf" /etc/asterisk/

    # The Asterisk package creates an 'asterisk' user and group.
    # We must ensure this user owns the config files.
    chown asterisk:asterisk /etc/asterisk/*.conf

    echo "Restarting Asterisk with new configuration..."
    systemctl restart asterisk
    echo "Asterisk configured and restarted."
else
    echo "Error: Asterisk config directory not found at '$ASTERISK_CONFIG_DIR'."
    exit 1
fi

# --- Configure PostgreSQL ---
echo ""
echo "Configuring PostgreSQL..."

# Check if the .env file exists to get credentials
ENV_FILE="$PROJECT_ROOT/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Please create it from .env.example first."
    exit 1
fi

# Source the .env file to get variables, using a fallback for safety
set -a
source "$ENV_FILE"
set +a

# Check if required variables are set
: "${POSTGRES_DB?Error: POSTGRES_DB is not set in .env file.}"
: "${POSTGRES_USER?Error: POSTGRES_USER is not set in .env file.}"
: "${POSTGRES_PASSWORD?Error: POSTGRES_PASSWORD is not set in .env file.}"

# Use sudo -u postgres to run psql commands as the postgres user
# Check if the database already exists
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$POSTGRES_DB"; then
    echo "Database '$POSTGRES_DB' already exists. Skipping database creation."
else
    echo "Creating database '$POSTGRES_DB'..."
    sudo -u postgres psql -c "CREATE DATABASE $POSTGRES_DB;"
fi

# Check if the user already exists
if sudo -u postgres psql -c '\du' | grep -q "$POSTGRES_USER"; then
    echo "User '$POSTGRES_USER' already exists. Skipping user creation."
else
    echo "Creating user '$POSTGRES_USER'..."
    sudo -u postgres psql -c "CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;"
fi

echo "PostgreSQL configured successfully."
echo ""
echo "========================================================================"
echo "Service configuration complete."
echo "========================================================================"

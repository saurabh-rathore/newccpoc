#!/bin/bash

# This script contains common functions and variables to be used across the deployment scripts.

# --- Common Functions ---
function print_header() {
    echo ""
    echo "========================================================================"
    echo " $1"
    echo "========================================================================"
}

# Ensure the script is run with root privileges
function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root."
        exit 1
    fi
}

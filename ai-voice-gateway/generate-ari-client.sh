#!/bin/bash
set -e

echo "========================================================================"
echo "Generating Python 3 ARI Client from Asterisk's OpenAPI Specification"
echo "========================================================================"

# This script must be run from the 'ai-voice-gateway' directory.
if [ ! -f "main.py" ]; then
    echo "Error: This script must be run from within the 'ai-voice-gateway' directory."
    exit 1
fi

# The openapi-python-client should be installed by the parent script
# into the correct virtual environment.

# Fetch the OpenAPI spec from the running Asterisk container
echo "Fetching ari.json from Asterisk..."
curl -o ari.json http://localhost:8088/ari/api-docs/docs.json

# Check if the download was successful
if [ ! -s "ari.json" ]; then
    echo "Error: Failed to download ari.json from Asterisk. Is ARI enabled and http running?"
    exit 1
fi

# Generate the client
echo "Generating the ARI client library..."
# We remove any old client to ensure a clean generation
rm -rf ./ari_client
openapi-python-client generate --path ./ari.json --config ./pyproject.toml

# Clean up the downloaded spec file
rm ari.json

echo "========================================================================"
echo "ARI client generated successfully in the 'ari_client' directory."
echo "========================================================================"

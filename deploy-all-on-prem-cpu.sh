#!/bin/bash
set -e

# This master script runs all the individual on-premise CPU deployment scripts
# in the correct order. It provides a "one-click" deployment experience while
# still allowing individual scripts to be run for debugging or manual setup.

# Ensure the script is run from the project root
if [ ! -d "on-prem-deployment" ]; then
    echo "Error: This script must be run from the root of the project directory."
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

echo "========================================================================"
echo "Starting the Full On-Premise CPU Deployment..."
echo "========================================================================"
echo "This will execute all four setup scripts in sequence."
echo ""

# Make all scripts in the deployment directory executable
chmod +x on-prem-deployment/*.sh

# Execute each script in order, passing control to it
./on-prem-deployment/01-setup-host.sh
./on-prem-deployment/02-setup-kubernetes-cluster.sh
./on-prem-deployment/03-setup-onprem-components.sh
./on-prem-deployment/04-build-and-deploy-app.sh

echo ""
echo "========================================================================"
echo "All deployment steps completed successfully!"
echo "The AI Call Center application should now be running on your Kubernetes cluster."
echo "Use 'kubectl get pods -n ai-call-center' to check the status."
echo "========================================================================"

#!/bin/bash

# =================================================================================
# AI Voice Call Center - Automated On-Premise Kubernetes Deployment Script
# =================================================================================
# This script is designed to be run on a fresh, GPU-enabled Ubuntu 22.04 server.
# It will install all prerequisites, set up a single-node Kubernetes cluster,
# and deploy the full application stack.
#
# USAGE: sudo ./deploy-on-prem.sh
# =================================================================================

set -e # Exit immediately on error

# --- Helper Functions ---
function print_header() {
    echo ""
    echo "================================================================================"
    echo " $1"
    echo "================================================================================"
}

# ... (rest of script is the same until the final instructions)

# --- Final Instructions ---
print_header "On-Premise Deployment Complete!"
echo "A single-node Kubernetes cluster has been created and the application is deployed."
echo "It may take several minutes for all pods to be in the 'Running' state."
echo "You can check the status by running the following command:"
echo "kubectl get pods -n ai-call-center -w"
echo ""
echo "The external IP for the SIP service is: ${HOST_IP}"
echo "Use this IP in your SIP client to place a test call."
echo ""
print_header "IMPORTANT: If 'kubectl' commands fail with 'connection refused'"
echo "This is a common issue because the script was run with 'sudo'."
echo "To fix this, run the following three commands to grant your regular user"
echo "access to the new Kubernetes cluster:"
echo ""
echo "mkdir -p \$HOME/.kube"
echo "sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""
echo "After running these commands, 'kubectl' will work correctly."
echo "Enjoy your on-premise AI Call Center!"

exit 0

#!/bin/bash

# =================================================================================
# AI Voice Call Center - Automated On-Premise CPU-Only Deployment Script
# =================================================================================
# This script is designed to be run on a fresh Ubuntu 22.04 server (CPU-only).
# It will install all prerequisites, set up a single-node Kubernetes cluster,
# and deploy the full application stack for functional testing.
#
# USAGE: sudo ./deploy-on-prem-cpu.sh
# =================================================================================

set -e # Exit immediately on error

# --- Helper Functions ---
# ... (script content is the same until the final instructions)

# --- Final Instructions ---
print_header "CPU-Only On-Premise Deployment Complete!"
echo "A single-node Kubernetes cluster has been created and the application is deployed."
echo "WARNING: Performance will be very slow. This is for functional testing only."
echo "You can check the status of the pods by running the following command:"
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

exit 0

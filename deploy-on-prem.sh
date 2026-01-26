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
# ... (script is the same until Step 5)

# --- Step 5: Initialize Kubernetes Cluster ---
print_header "Initializing Single-Node Kubernetes Cluster with kubeadm"
if [ ! -f /etc/kubernetes/admin.conf ]; then
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Create the kubeadm config file with the corrected structure
    cat <<EOF | tee kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podNetworkCidr: "192.168.0.0/16"
EOF

    kubeadm init --config kubeadm-config.yaml

    # ... (rest of script is the same until MetalLB installation)
fi

# --- Step 6: Setup On-Premise Components ---
print_header "Setting up On-Premise Kubernetes Components"
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml

# Use the corrected MetalLB URL
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

sleep 15
# ... (rest of script is the same)

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

function wait_for_apt_lock() {
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
       echo "Waiting for other package manager processes (like unattended-upgrades) to finish..."
       sleep 5
    done
}

# --- Pre-flight Checks ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (sudo ./deploy-on-prem.sh)"
    exit 1
fi

# --- Step 1: Install NVIDIA Drivers (if needed) ---
# ... (script is the same until Step 5)

# --- Step 5: Initialize Kubernetes Cluster ---
print_header "Initializing Single-Node Kubernetes Cluster with kubeadm"
if [ ! -f /etc/kubernetes/admin.conf ]; then
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Create the kubeadm config file to specify the CRI socket
    cat <<EOF | tee kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
podNetworkCidr: "192.168.0.0/16"
EOF

    # Initialize the cluster using the config file
    kubeadm init --config kubeadm-config.yaml

    # ... (rest of the script remains the same)

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    if [ -n "$SUDO_USER" ]; then
        mkdir -p /home/$SUDO_USER/.kube
        cp -i /etc/kubernetes/admin.conf /home/$SUDO_USER/.kube/config
        chown $SUDO_UID:$SUDO_GID /home/$SUDO_USER/.kube/config
    fi

    echo "Waiting for Kubernetes API server to be ready..."
    until kubectl get nodes > /dev/null 2>&1; do
        echo "API server not ready yet. Waiting..."
        sleep 5
    done
    echo "Kubernetes API server is ready."

    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
else
    echo "Kubernetes cluster already initialized. Skipping."
fi

# ... (rest of script is the same)

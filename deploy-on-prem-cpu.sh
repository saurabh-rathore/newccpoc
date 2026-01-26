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
# ... (script is the same until Step 4)

# --- Step 4: Initialize Kubernetes Cluster ---
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

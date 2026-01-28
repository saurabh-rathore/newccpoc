#!/bin/bash
set -e
source ./on-prem-deployment/common.sh

print_header "Step 1: Installing Prerequisites (Docker & Kubernetes Tools)"

# --- Install Container Runtime (Docker) ---
if ! command -v docker &> /dev/null; then
    print_header "Installing Docker Engine"
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y docker-ce docker-ce-cli containerd.io
else
    echo "Docker already installed. Skipping."
fi

# --- Install Kubernetes Tools ---
if ! command -v kubeadm &> /dev/null; then
    print_header "Installing Kubernetes Tools (kubeadm, kubelet, kubectl)"
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
else
    echo "Kubernetes tools already installed. Skipping."
fi

echo "Prerequisites installed successfully."

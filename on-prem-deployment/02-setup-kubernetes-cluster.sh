#!/bin/bash
set -e
source ./on-prem-deployment/common.sh

print_header "Step 2: Kubernetes Cluster Setup (kubeadm)"

# --- Check for Root ---
check_root

# --- Install Kubernetes Components ---
if ! command -v kubeadm &> /dev/null; then
    print_header "Installing kubeadm, kubelet, and kubectl..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg

    # New GPG key location for Kubernetes
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    echo "Kubernetes components installed."
else
    echo "Kubernetes components (kubeadm, etc.) are already installed. Skipping."
fi

# --- Initialize Kubernetes Cluster ---
if ! kubectl cluster-info &> /dev/null; then
    print_header "Initializing Kubernetes cluster with kubeadm..."
    # Using a non-standard port to avoid conflicts with other services
    # And specifying a pod network CIDR that is compatible with Calico
    kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

    print_header "Configuring kubectl for the root user..."
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    echo "Kubernetes cluster initialized successfully."

    echo "Waiting for Kubernetes API server to be ready..."
    until kubectl get nodes &> /dev/null; do
        echo "API server not ready yet. Retrying in 5 seconds..."
        sleep 5
    done
    echo "API server is ready."
else
    echo "Kubernetes cluster is already running. Skipping initialization."
fi

# --- Install CNI (Calico) ---
print_header "Installing Calico CNI"
# Check if Calico is already installed by looking for one of its key deployments
if ! kubectl get deployment -n kube-system calico-kube-controllers &> /dev/null; then
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
    echo "Calico CNI installed. It may take a minute for all pods to be ready."
else
    echo "Calico CNI appears to be already installed. Skipping."
fi

# --- Untaint Control-Plane Node ---
print_header "Allowing pods to be scheduled on the control-plane node"
# This is for single-node development clusters. Remove this in a multi-node production setup.
if kubectl get nodes -o jsonpath='{.items[?(@.spec.taints)].metadata.name}' | grep -q "$(hostname)"; then
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    echo "Control-plane node untainted."
else
   echo "Control-plane node already untainted. Skipping."
fi

echo "Kubernetes cluster setup complete."

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
if ! command -v nvidia-smi &> /dev/null; then
    print_header "Installing NVIDIA Drivers and Container Toolkit"
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y curl gnupg
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y cuda-drivers nvidia-container-toolkit
    print_header "NVIDIA Drivers Installed. A reboot is required."
    echo "Please reboot your server and then run this script again to continue."
    exit 0
else
    echo "NVIDIA drivers already installed. Skipping."
fi

# --- Step 2: Install Container Runtime (Docker/containerd) ---
print_header "Installing Container Runtime"
if ! command -v docker &> /dev/null; then
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    wait_for_apt_lock; apt-get update
    wait_for_apt_lock; apt-get install -y docker-ce docker-ce-cli containerd.io
else
    echo "Container runtime already installed. Skipping."
fi

# --- Step 3: Install Kubernetes Tools ---
print_header "Installing Kubernetes Tools (kubeadm, kubelet, kubectl)"
if ! command -v kubeadm &> /dev/null; then
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

# --- Step 4: Prepare System for Kubernetes ---
print_header "Preparing System for Kubernetes"
# Load required kernel modules
modprobe overlay
modprobe br_netfilter

# Set required sysctl params for Kubernetes networking
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Reset containerd config to be compatible with Kubernetes CRI
rm -f /etc/containerd/config.toml
systemctl restart containerd
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# --- Step 5: Initialize Kubernetes Cluster ---
print_header "Initializing Single-Node Kubernetes Cluster with kubeadm"
if [ ! -f /etc/kubernetes/admin.conf ]; then
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab # Disable swap permanently
    kubeadm init --pod-network-cidr=192.168.0.0/16

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    if [ -n "$SUDO_USER" ]; then
        mkdir -p /home/$SUDO_USER/.kube
        cp -i /etc/kubernetes/admin.conf /home/$SUDO_USER/.kube/config
        chown $SUDO_UID:$SUDO_GID /home/$SUDO_USER/.kube/config
    fi

    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
else
    echo "Kubernetes cluster already initialized. Skipping."
fi

# --- Step 6: Setup On-Premise Components ---
print_header "Setting up On-Premise Kubernetes Components"
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/native/metallb-native.yaml
sleep 15
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s
HOST_IP=$(hostname -I | awk '{print $1}')
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${HOST_IP}-${HOST_IP}
EOF
docker run -d -p 5000:5000 --restart=always --name registry registry:2
cat << EOF > /etc/docker/daemon.json
{
  "insecure-registries" : ["localhost:5000"]
}
EOF
systemctl restart docker

# --- Step 7: Build and Push Images ---
print_header "Building and pushing service images to local registry"
SERVICES=("ai-voice-gateway" "stt-service" "llm-service" "tts-service" "asterisk")
for SERVICE in "${SERVICES[@]}"; do
    docker build -t "localhost:5000/${SERVICE}:latest" "./${SERVICE}"
    docker push "localhost:5000/${SERVICE}:latest"
done

# --- Step 8: Deploy the Application ---
print_header "Deploying the AI Voice Call Center Application"
mkdir -p ./.tmp_onprem_manifests
for FILE in kubernetes/*.yaml; do
    sed -e "s|<your_docker_registry>/|localhost:5000/|g" \
        -e "s|storageClassName: \"gp2\"|# storageClassName: \"gp2\"|g" \
        "$FILE" > "./.tmp_onprem_manifests/$(basename "$FILE")"
done
kubectl apply -f ./.tmp_onprem_manifests/00-namespace.yaml
kubectl apply -f ./.tmp_onprem_manifests/05-secrets.yaml
kubectl apply -f ./.tmp_onprem_manifests/

# --- Final Instructions ---
print_header "On-Premise Deployment Complete!"
echo "Run 'kubectl get pods -n ai-call-center -w' to check status."
echo "The external IP for the SIP service is: ${HOST_IP}"
exit 0

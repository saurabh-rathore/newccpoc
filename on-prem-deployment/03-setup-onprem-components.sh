#!/bin/bash
set -e
source ./on-prem-deployment/common.sh

print_header "Step 3: Setting Up On-Premise Components (MetalLB & Registry)"

# --- Check for Root ---
check_root

# --- Setup MetalLB ---
print_header "Setting up MetalLB for Load Balancing"
if ! kubectl get namespace metallb-system &> /dev/null; then
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    echo "MetalLB applied. Waiting for webhook to be ready..."
    # Wait for the deployment of the controller to be available, which is a reliable signal the webhook is ready
    kubectl wait --namespace metallb-system \
                    --for=condition=available deployment \
                    --selector=component=controller \
                    --timeout=300s
    echo "MetalLB webhook is ready."
else
    echo "MetalLB namespace already exists. Assuming it's configured. Skipping install."
fi

# Apply the IPAddressPool configuration if it doesn't exist
if ! kubectl get ipaddresspool -n metallb-system default-pool &> /dev/null; then
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
    echo "MetalLB IPAddressPool configured."
else
    echo "MetalLB IPAddressPool 'default-pool' already exists. Skipping configuration."
fi

# --- Setup Local Docker Registry ---
print_header "Setting up Local Docker Registry"
if [ ! "$(docker ps -q -f name=registry)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=registry)" ]; then
        echo "Removing exited registry container."
        docker rm registry
    fi
    echo "Starting local Docker registry..."
    docker run -d -p 5000:5000 --restart=always --name registry registry:2
else
    echo "Local registry is already running. Skipping."
fi

# --- Configure Docker for Local Registry ---
if ! grep -q "localhost:5000" /etc/docker/daemon.json; then
    echo "Configuring Docker to trust local registry..."
    cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "insecure-registries" : ["localhost:5000"]
}
EOF
    systemctl restart docker
    echo "Docker daemon configured and restarted."
else
    echo "Docker daemon already configured for local registry. Skipping."
fi

echo "On-premise components set up successfully."

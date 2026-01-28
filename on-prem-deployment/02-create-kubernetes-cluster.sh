#!/bin/bash
set -e
source ./on-prem-deployment/common.sh

print_header "Step 2: Creating the Kubernetes Cluster"

# --- Prepare System for Kubernetes ---
print_header "Preparing System for Kubernetes"
modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system
rm -f /etc/containerd/config.toml
systemctl restart containerd
systemctl restart docker

# --- Initialize Kubernetes Cluster ---
if [ ! -f /etc/kubernetes/admin.conf ]; then
    print_header "Initializing Single-Node Kubernetes Cluster with kubeadm"
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    cat <<EOF | tee kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: "192.168.0.0/16"
EOF

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

echo "Kubernetes cluster created successfully."

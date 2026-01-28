#!/bin/bash
set -e
source ./on-prem-deployment/common.sh

print_header "Step 1: Host-level Prerequisite Setup"

# --- Check for Root ---
check_root

# --- Install Docker ---
if ! command -v docker &> /dev/null; then
    print_header "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "Docker is already installed. Skipping."
fi

# --- Configure Docker cgroup driver ---
print_header "Configuring Docker to use systemd cgroup driver"
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl enable docker
systemctl daemon-reload
systemctl restart docker
echo "Docker configuration complete."

# --- Disable Swap ---
if [ "$(swapon --show)" ]; then
    print_header "Disabling swap..."
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "Swap disabled."
else
    echo "Swap is already disabled. Skipping."
fi

# --- Load Kernel Modules ---
print_header "Loading required kernel modules"
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# --- Configure sysctl for Kubernetes networking ---
print_header "Configuring sysctl for Kubernetes networking"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "Host setup complete."

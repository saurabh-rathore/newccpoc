#!/bin/bash

# =================================================================================
# AI Voice Call Center - Automated EKS Deployment Script
# =================================================================================
# This script automates the creation of a production-grade EKS cluster
# and the deployment of the entire application stack.
#
# Prerequisites:
#   - AWS CLI configured with administrator access.
#   - kubectl installed.
#   - eksctl installed.
#   - Docker running locally.
# =================================================================================

set -e # Exit immediately on error

# --- Helper Functions ---
function check_command() {
    command -v "$1" >/dev/null 2>&1
}

function print_header() {
    echo ""
    echo "================================================================================"
    echo " $1"
    echo "================================================================================"
}

# --- Configuration (User will be prompted) ---
AWS_REGION=""
CLUSTER_NAME="ai-call-center-cluster"
ECR_REPOSITORY_PREFIX=""

# --- Prerequisite Check ---
print_header "Checking for required tools..."
if ! check_command aws; then echo "Error: AWS CLI is not installed."; exit 1; fi
if ! check_command kubectl; then echo "Error: kubectl is not installed."; exit 1; fi
if ! check_command eksctl; then echo "Error: eksctl is not installed."; exit 1; fi
if ! docker info >/dev/null 2>&1; then echo "Error: Docker is not running."; exit 1; fi
echo "All required tools are present."

# --- User Input ---
print_header "Please provide the following configuration:"
read -p "Enter your AWS Region (e.g., us-east-1): " AWS_REGION
read -p "Enter a prefix for your ECR repositories (e.g., my-company-ai): " ECR_REPOSITORY_PREFIX

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# --- Step 1: Create EKS Cluster ---
print_header "Creating EKS Cluster with GPU nodes (this will take ~20 minutes)..."
cat << EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
nodeGroups:
  - name: standard-workers
    instanceType: t3.medium
    desiredCapacity: 2
  - name: gpu-workers
    instanceType: g4dn.xlarge
    desiredCapacity: 2
    taints:
      - key: nvidia.com/gpu
        value: "true"
        effect: NoSchedule
EOF

eksctl create cluster -f cluster.yaml
echo "EKS Cluster created successfully."

# --- Step 2: Create ECR Repositories and Push Images ---
print_header "Setting up ECR and pushing Docker images..."
SERVICES=("ai-voice-gateway" "stt-service" "llm-service" "tts-service" "asterisk")

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY_URL}

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="${ECR_REPOSITORY_PREFIX}/${SERVICE}"
    echo "--- Processing service: ${SERVICE} ---"

    # Create ECR repo if it doesn't exist
    aws ecr describe-repositories --repository-names ${REPO_NAME} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${REPO_NAME}

    # Build, tag, and push the image
    docker build -t "${ECR_REGISTRY_URL}/${REPO_NAME}:latest" "./${SERVICE}"
    docker push "${ECR_REGISTRY_URL}/${REPO_NAME}:latest"
    echo "--- Finished service: ${SERVICE} ---"
done

# --- Step 3: Update and Apply Kubernetes Manifests ---
print_header "Updating and deploying Kubernetes manifests..."
# Create a temporary directory for the updated manifests
mkdir -p ./.tmp_k8s_manifests

# Replace placeholders in manifests
for FILE in kubernetes/*.yaml; do
    sed "s|<your_docker_registry>|${ECR_REGISTRY_URL}/${ECR_REPOSITORY_PREFIX}|g" "$FILE" > "./.tmp_k8s_manifests/$(basename "$FILE")"
done

echo "Applying manifests to EKS cluster..."
kubectl apply -f ./.tmp_k8s_manifests/00-namespace.yaml
kubectl apply -f ./.tmp_k8s_manifests/05-secrets.yaml # Apply secrets first
kubectl apply -f ./.tmp_k8s_manifests/

# Clean up temporary files
rm -rf ./.tmp_k8s_manifests
rm cluster.yaml

# --- Step 4: Final Instructions ---
print_header "Deployment to EKS is complete!"
echo "It may take a few minutes for the LoadBalancers to be provisioned and for all pods to be in the 'Running' state."
echo "Run the following command to watch the status of your services and get the external IPs:"
echo "kubectl get services -n ai-call-center -w"
echo ""
echo "Once the 'asterisk-loadbalancer' has an EXTERNAL-IP, you can use it in your SIP client."
echo "Please update the 'gateway-loadbalancer' EXTERNAL-IP in your '01-ai-voice-gateway.yaml' manifest and re-apply it if needed for the media stream."

exit 0

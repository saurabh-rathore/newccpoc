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

    aws ecr describe-repositories --repository-names ${REPO_NAME} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${REPO_NAME}

    docker build -t "${ECR_REGISTRY_URL}/${REPO_NAME}:latest" "./${SERVICE}"
    docker push "${ECR_REGISTRY_URL}/${REPO_NAME}:latest"
    echo "--- Finished service: ${SERVICE} ---"
done

# --- Step 3: Update and Apply Kubernetes Manifests ---
print_header "Updating and deploying Kubernetes manifests..."
mkdir -p ./.tmp_k8s_manifests

for FILE in kubernetes/*.yaml; do
    sed "s|<your_docker_registry>|${ECR_REGISTRY_URL}/${ECR_REPOSITORY_PREFIX}|g" "$FILE" > "./.tmp_k8s_manifests/$(basename "$FILE")"
done

echo "Applying manifests to EKS cluster..."
kubectl apply -f ./.tmp_k8s_manifests/00-namespace.yaml
kubectl apply -f ./.tmp_k8s_manifests/05-secrets.yaml
kubectl apply -f ./.tmp_k8s_manifests/

# --- Step 4: Automatically Configure Gateway External URL ---
print_header "Waiting for Gateway Load Balancer to get an external hostname..."
GATEWAY_URL=""
while [ -z "$GATEWAY_URL" ]; do
  echo "Waiting for external IP..."
  GATEWAY_URL=$(kubectl get service gateway-loadbalancer -n ai-call-center -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  [ -z "$GATEWAY_URL" ] && sleep 10
done
echo "Gateway URL found: ${GATEWAY_URL}"

print_header "Injecting external URL into the AI Voice Gateway deployment..."
GATEWAY_WS_URL_BASE="ws://${GATEWAY_URL}/ws/media/"
kubectl set env deployment/ai-voice-gateway -n ai-call-center "GATEWAY_WS_URL_BASE=${GATEWAY_WS_URL_BASE}"

# Clean up temporary files
rm -rf ./.tmp_k8s_manifests
rm cluster.yaml

# --- Step 5: Final Instructions ---
print_header "Deployment to EKS is complete and fully configured!"
echo "It may take a few more minutes for the gateway pods to restart with the new environment variable."
echo "Run the following command to get the external IP for your SIP client:"
echo "kubectl get service asterisk-loadbalancer -n ai-call-center"

exit 0

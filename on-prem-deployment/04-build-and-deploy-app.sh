#!/bin/bash
set -e
source ./on-prem-deployment/common.sh

print_header "Step 4: Building and Deploying the AI Call Center Application"

# --- Build Docker Images ---
print_header "Building application Docker images"
# Use the CPU-specific docker-compose file
if [ -f "docker-compose.cpu.yml" ]; then
    docker-compose -f docker-compose.cpu.yml build
else
    echo "Error: docker-compose.cpu.yml not found!"
    exit 1
fi

# --- Tag and Push Images to Local Registry ---
print_header "Tagging and pushing images to local registry (localhost:5000)"
IMAGES=(
    "ai-voice-gateway"
    "ai-llm-service"
    "ai-stt-service"
    "ai-tts-service"
)

for img in "${IMAGES[@]}"; do
    echo "Processing image: $img"
    if docker image inspect "${img}:latest" &> /dev/null; then
        docker tag "${img}:latest" "localhost:5000/${img}:latest"
        docker push "localhost:5000/${img}:latest"
    else
        echo "Warning: Image ${img}:latest not found. Skipping tag and push."
    fi
done

# --- Deploy to Kubernetes ---
print_header "Deploying application to Kubernetes"

# Ensure the namespace exists
if ! kubectl get namespace ai-call-center &> /dev/null; then
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ai-call-center
EOF
    echo "Namespace 'ai-call-center' created."
else
    echo "Namespace 'ai-call-center' already exists."
fi

# Create a temporary directory for modified manifests
mkdir -p /tmp/k8s_manifests

# Modify manifests to use local registry and apply them
MANIFEST_DIR="kubernetes-cpu"
TEMP_MANIFEST_DIR="/tmp/k8s_manifests_modified"

if [ ! -d "$MANIFEST_DIR" ]; then
    echo "Error: Manifest directory '$MANIFEST_DIR' not found!"
    exit 1
fi

rm -rf "$TEMP_MANIFEST_DIR"
mkdir -p "$TEMP_MANIFEST_DIR"

echo "Modifying manifests to use local registry..."
for yaml_file in "$MANIFEST_DIR"/*.yaml; do
    if [ -f "$yaml_file" ]; then
        # This sed command finds lines with 'image:' and prefixes the image name with 'localhost:5000/'
        # It assumes image names are like 'ai-llm-service', etc. and avoids touching other 'image:' lines.
        sed 's|image: \(ai-.*\)|image: localhost:5000/\1|g' "$yaml_file" > "$TEMP_MANIFEST_DIR/$(basename "$yaml_file")"
    fi
done

echo "Applying all modified manifests from '$TEMP_MANIFEST_DIR'..."
kubectl apply -f "$TEMP_MANIFEST_DIR"

# Clean up temporary files
rm -rf /tmp/k8s_manifests

print_header "Deployment complete!"
echo "You can monitor the status of the pods by running:"
echo "kubectl get pods -n ai-call-center -w"

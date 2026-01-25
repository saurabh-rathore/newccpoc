# EC2 Deployment and Production Readiness Guide

This guide provides simplified instructions for deploying the AI Voice Call Center on an AWS EC2 instance and offers a detailed analysis of its production readiness.

---

## Part 1: Single-Node Deployment (Prototype/Demo)

### EC2 Instance Requirements: A Critical Note

You mentioned an "Amazon EC2 medium instance." It is critical to understand that **standard instance types (like `t2.medium`, `t3.medium`, etc.) will not work.**

This application relies on multiple large AI models that require significant computational power. Therefore, **a GPU-enabled instance is mandatory.**

**Recommended EC2 Instance Type:**
*   **`g4dn.xlarge`**: This is an excellent starting point. It provides a good balance of CPU, RAM, and a dedicated NVIDIA T4 GPU, which is well-suited for AI inference tasks.

When launching your instance from the AWS EC2 console, be sure to select an **Ubuntu 22.04 LTS** Amazon Machine Image (AMI).

### Simplified Deployment Steps for EC2

Once you have launched your `g4dn.xlarge` (or similar) instance and connected to it via SSH, the deployment process is very straightforward thanks to the automation script.

**Follow these exact steps:**

**Step 1: Clone the Project**

First, get the code from the repository.

```bash
# Install git (it may not be on the default Ubuntu AMI)
sudo apt-get update && sudo apt-get install -y git

# Clone your repository
git clone <your_repository_url>

# Navigate into the project directory
cd <your_project_directory>
```

**Step 2: Run the Automated Deployment Script**

Now, execute the deployment script with `sudo`. This script handles everything from installing Docker and NVIDIA drivers to building and launching the application.

```bash
# Make the script executable
chmod +x deploy.sh

# Run the deployment script as a superuser
sudo ./deploy.sh
```

**Important:** The script will likely require a **reboot** after installing the NVIDIA drivers. After your EC2 instance reboots, SSH back into it, navigate back to the project directory, and **run the script again:**

```bash
cd <your_project_directory>
sudo ./deploy.sh
```

The second run will complete the setup by building the Docker images (which will take some time) and launching all the services. The system will then be live and ready to take calls. You can follow the verification steps in the `DEPLOYMENT_GUIDE.md` to place a test call.

---

## Part 2: Production-Grade Deployment with Kubernetes (EKS)

The steps below outline how to deploy the application in a scalable, highly-available production environment using Amazon EKS (Elastic Kubernetes Service).

### Step 1: Set Up an EKS Cluster

1.  **Install `eksctl` and `kubectl`:** Follow the official AWS documentation to install these command-line tools on your local machine.
2.  **Create a Cluster Configuration File:** Create a file named `cluster.yaml` with the following content. This defines a cluster with a standard node group for stateless services and a GPU-powered node group for the AI services.

    ```yaml
    apiVersion: eksctl.io/v1alpha5
    kind: ClusterConfig

    metadata:
      name: ai-call-center-cluster
      region: <your-aws-region>

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
    ```
3.  **Launch the Cluster:**
    ```bash
    eksctl create cluster -f cluster.yaml
    ```
    *(This will take 15-20 minutes to provision).*

### Step 2: Build and Push Docker Images

The Kubernetes cluster needs access to the service images. You cannot build them locally on the cluster nodes. Instead, you must build them and push them to a container registry like Amazon ECR (Elastic Container Registry).

1.  **Create ECR Repositories:** For each service (`ai-voice-gateway`, `stt-service`, etc.), create a repository in the ECR console.
2.  **Authenticate Docker with ECR:**
    ```bash
    aws ecr get-login-password --region <your-aws-region> | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.<your-aws-region>.amazonaws.com
    ```
3.  **Build, Tag, and Push each image:**
    ```bash
    # For the ai-voice-gateway service
    docker build -t <your_ecr_repo_uri>/ai-voice-gateway:latest ./ai-voice-gateway
    docker push <your_ecr_repo_uri>/ai-voice-gateway:latest

    # Repeat for stt-service, llm-service, and tts-service
    ```

### Step 3: Deploy to EKS

1.  **Update Manifests:**
    *   In the `kubernetes/*.yaml` files, replace all instances of `<your_docker_registry>` with your actual ECR repository URI.
    *   In `kubernetes/05-secrets.yaml`, replace the placeholder values with your actual database credentials.
2.  **Apply the Manifests:**
    ```bash
    # Apply the namespace, then secrets, then all other configurations
    kubectl apply -f kubernetes/00-namespace.yaml
    kubectl apply -f kubernetes/05-secrets.yaml
    kubectl apply -f kubernetes/
    ```
3.  **Get Load Balancer IPs:**
    ```bash
    kubectl get services -n ai-call-center -w # Wait for the LoadBalancer IPs
    ```
    Once the `asterisk-loadbalancer` and `gateway-loadbalancer` have external IPs, the system is live. You will need to use the `asterisk-loadbalancer` IP in your SIP client.

This Kubernetes setup provides the scalability and high availability needed for a true production deployment.

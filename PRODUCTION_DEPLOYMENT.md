# Production Deployment Guide

This guide provides instructions for deploying the AI Voice Call Center to a production-grade Kubernetes cluster. It covers two primary scenarios:
1.  **Automated Deployment to AWS EKS:** Using the `deploy-eks.sh` script for a single-run setup.
2.  **Manual Deployment to an On-Premise Cluster:** Using the provided Kubernetes manifests with necessary modifications.

---

## Part 1: Automated Deployment to AWS EKS

This method uses the `deploy-eks.sh` script to automate the entire setup process.

### Prerequisites for `deploy-eks.sh`

The `deploy-eks.sh` script should be run from your **local machine**, not from an EC2 instance. Before you run it, you must have the following tools installed and configured:

1.  **AWS CLI:**
    *   **Why it's needed:** To create and manage AWS resources like EKS clusters and ECR repositories.
    *   **Configuration:** You must configure it with an IAM user that has administrator-level permissions. Run `aws configure` and provide your Access Key ID, Secret Access Key, and default region.

2.  **`eksctl`:**
    *   **Why it's needed:** This is the official AWS tool for creating and managing EKS clusters. The script uses it to provision the entire Kubernetes cluster, including the GPU-enabled node groups.

3.  **`kubectl`:**
    *   **Why it's needed:** This is the standard command-line tool for interacting with any Kubernetes cluster. The script uses it to deploy the application by applying the YAML manifest files.

4.  **Docker:**
    *   **Why it's needed:** The script uses your local Docker daemon to build the application's container images before pushing them to the Amazon ECR (Elastic Container Registry).
    *   **Requirement:** Ensure the Docker service is running on your local machine.

### Running the Script

Once the prerequisites are met, you can launch the entire production environment with a single command from the project's root directory:

```bash
./deploy-eks.sh
```
The script will handle the rest, as detailed in the `EC2_DEPLOYMENT_AND_PRODUCTION_GUIDE.md`.

---

## Part 2: Manual Deployment to an On-Premise Cluster

Yes, the system is designed to be platform-agnostic and can absolutely be deployed to an on-premise Kubernetes cluster (e.g., created with `kubeadm`, Rancher, or VMware Tanzu).

The automated `deploy-eks.sh` script will not work for this, but the core Kubernetes manifests located in the `kubernetes/` directory are your foundation. You will need to apply them manually after making a few necessary adjustments for your specific on-premise environment.

### Step 1: On-Premise GPU Setup

*   **Requirement:** You must have physical servers with NVIDIA GPUs.
*   **Action:** You need to install the **NVIDIA Device Plugin for Kubernetes**. This plugin runs on your cluster nodes and automatically exposes the GPUs as schedulable resources, allowing `kubectl` to honor the `nvidia.com/gpu: 1` resource limits in the AI service deployment files.

### Step 2: On-Premise Networking (Load Balancing)

*   **Challenge:** On-premise clusters do not have a native cloud load balancer. The `type: LoadBalancer` in the `04-loadbalancers.yaml` manifest will not work out-of-the-box.
*   **Solution:** Use a tool like **MetalLB**. MetalLB provides a network load-balancer implementation for bare-metal Kubernetes clusters, integrating with your local network.
*   **Action:**
    1.  Install MetalLB on your cluster.
    2.  Create a `ConfigMap` for MetalLB to assign it a pool of IP addresses from your local network that it is allowed to use.
    3.  You will need to create a new manifest file (an example `06-onprem-networking.yaml` is provided) that uses MetalLB to expose the SIP and WebSocket services.

### Step 3: On-Premise Storage

*   **Challenge:** The `03-stateful-services.yaml` manifest specifies `storageClassName: "gp2"`, which is specific to AWS.
*   **Solution:** You need to replace this with the name of a `StorageClass` that is available in your on-premise cluster. This will depend on your storage solution (e.g., Ceph, GlusterFS, or a commercial SAN).
*   **Action:**
    1.  Find your available StorageClasses: `kubectl get storageclass`.
    2.  Edit `kubernetes/03-stateful-services.yaml` and replace `gp2` with the name of your on-premise `StorageClass`.

### Step 4: Image Registry

*   **Requirement:** Your Kubernetes cluster needs access to the Docker images for each service.
*   **Solution:** You must host a private Docker registry within your on-premise network (e.g., Harbor, Sonatype Nexus, or a simple Docker registry container).
*   **Action:**
    1.  Build the Docker images for each service as described in the EKS guide.
    2.  Push these images to your private registry.
    3.  In all the `kubernetes/*.yaml` manifest files, replace the `<your_docker_registry>` placeholder with the address of your private registry (e.g., `my-registry.my-company.local:5000/ai-call-center`).

### Summary of On-Premise Deployment Steps

1.  Set up an on-premise Kubernetes cluster with GPU-equipped nodes.
2.  Install the NVIDIA Device Plugin.
3.  Install and configure MetalLB for load balancing.
4.  Set up a private Docker registry and push all service images to it.
5.  Modify the `.yaml` manifests to point to your private registry and use your on-premise `StorageClass`.
6.  Apply the manifests to your cluster: `kubectl apply -f kubernetes/`.

# EC2 Deployment and Production Readiness Guide

This guide provides instructions for two deployment scenarios for the AI Voice Call Center:
1.  **Single-Node Deployment:** A quick setup on a single EC2 instance for demos and testing.
2.  **Production-Grade Kubernetes Deployment:** A fully automated setup for a scalable, high-availability production environment on AWS EKS.

---

## Part 1: Single-Node Deployment (Prototype/Demo)

### EC2 Instance Requirements

This deployment requires a **GPU-enabled instance**. Standard instances like `t2.medium` will not work.
*   **Recommended Instance:** `g4dn.xlarge` with an Ubuntu 22.04 LTS AMI.

### Simplified Deployment Steps for EC2

1.  **Clone the Project:**
    ```bash
    sudo apt-get update && sudo apt-get install -y git
    git clone <your_repository_url>
    cd <your_project_directory>
    ```
2.  **Run the Automated Deployment Script:**
    This script installs Docker, NVIDIA drivers, and then builds and runs the application using `docker-compose`.
    ```bash
    chmod +x deploy.sh
    sudo ./deploy.sh
    ```
    **Note:** A reboot is required after the NVIDIA drivers are installed. After rebooting, `cd` back into the project directory and run `sudo ./deploy.sh` a second time to complete the setup.

---

## Part 2: Production-Grade Deployment with Kubernetes (EKS)

This deployment uses the `deploy-eks.sh` script to automate the creation of a scalable, high-availability production environment on AWS EKS.

### Prerequisites (to be installed on your local machine)

Before running the script, ensure you have the following tools installed and configured:
1.  **AWS CLI:** Authenticated with an account that has administrator privileges.
2.  **`kubectl`:** The Kubernetes command-line tool.
3.  **`eksctl`:** The official command-line tool for creating EKS clusters.
4.  **Docker:** The Docker daemon must be running locally to build the service images.

### Single-Run Automated EKS Deployment

The `deploy-eks.sh` script automates every step of the production deployment. When you run it, it will:
1.  Prompt you for your desired AWS Region and a name for your container repositories.
2.  Create a production-grade EKS cluster with both standard and GPU-powered node groups.
3.  Create the necessary Amazon ECR repositories.
4.  Build, tag, and push the Docker images for all services to ECR.
5.  Dynamically update the Kubernetes manifest files with your specific ECR repository URIs.
6.  Deploy the entire application stack to the EKS cluster.

**To launch the production environment, run the following command from the project root on your local machine:**

```bash
chmod +x deploy-eks.sh
./deploy-eks.sh
```

The script will take 20-30 minutes to complete, as it is provisioning a full cloud infrastructure stack. Once finished, it will provide you with the command to watch the services and retrieve the external IP address for your SIP client. This single command is all that is needed to go from the source code to a fully deployed, scalable production system.

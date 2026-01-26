# Production Deployment Guide

This guide provides instructions for deploying the AI Voice Call Center to a Kubernetes cluster. It covers three scenarios:
1.  **Automated Production Deployment to AWS EKS (GPU Required):** The recommended path for a scalable, cloud-based system.
2.  **Automated Production Deployment to On-Premise (GPU Required):** For deploying to your own GPU-enabled hardware.
3.  **Automated Functional Testing Deployment to On-Premise (CPU-Only):** A special version for testing application logic on non-GPU hardware.

---

## Part 1: Production Deployment (GPU Required)

### Scenario A: Automated Deployment to AWS EKS

This method uses the `deploy-eks.sh` script for a single-run setup of a scalable, production-ready environment.

#### Prerequisites for `deploy-eks.sh` (run on your local machine)
1.  **AWS CLI:** Configured with administrator access.
2.  **`eksctl`:** The official AWS tool for creating EKS clusters.
3.  **`kubectl`:** The standard Kubernetes command-line tool.
4.  **Docker:** Must be running locally to build service images.

#### Running the Script
From the project's root directory on your local machine, run:
```bash
./deploy-eks.sh
```

---

### Scenario B: Automated Deployment to On-Premise Ubuntu (GPU Required)

This method uses the `deploy-on-prem.sh` script to set up a production-ready, single-node Kubernetes cluster on your own GPU-enabled Ubuntu server.

#### Prerequisites
- A fresh Ubuntu 22.04 server with a dedicated NVIDIA GPU and at least 32GB of RAM.
- Root or `sudo` access.

#### Running the Script
From the project's root directory on your on-premise server, run:
```bash
sudo ./deploy-on-prem.sh
```
**Note:** A reboot will be required after the NVIDIA drivers are installed. After rebooting, run the script again to complete the setup.

---

## Part 2: Functional Testing Deployment (CPU-Only)

This scenario is **strictly for functional testing** and is not suitable for demos or production use. It allows you to verify the application's call flow and logic on a standard, non-GPU Ubuntu server.

### CPU-Only Deployment: Critical Performance Warning

-   **Extreme Slowness:** AI model performance on a CPU is thousands of times slower than on a GPU. You will experience **very long delays** (potentially minutes) between speaking and receiving a response.
-   **Lower Quality Responses:** The CPU mode uses a much smaller, less capable language model (`distilgpt2`). The responses will not be representative of the full system's capabilities.
-   **Purpose:** The sole purpose of this deployment is to confirm that the services are communicating correctly and the call logic is functional.

### Automated Deployment to On-Premise Ubuntu (CPU-Only)

This method uses the `deploy-on-prem-cpu.sh` script. It will install all prerequisites (except NVIDIA drivers), set up a Kubernetes cluster, and deploy the CPU-compatible version of the application.

#### Prerequisites
- A fresh Ubuntu 22.04 server (CPU-only is acceptable).
- At least 16GB of RAM is recommended.
- Root or `sudo` access.

#### Running the Script
From the project's root directory on your on-premise server, run:
```bash
sudo ./deploy-on-prem-cpu.sh
```
This script does not require a reboot and will complete the entire setup in a single run.

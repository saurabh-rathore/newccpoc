# Troubleshooting Guide

This guide provides solutions to common errors and issues you may encounter during the deployment and operation of the AI Voice Call Center.

---

## Issue 1: `kubectl` commands fail with "connection refused"

### Symptoms

After running one of the on-premise deployment scripts (`deploy-on-prem.sh` or `deploy-on-prem-cpu.sh`), you try to run a `kubectl` command (e.g., `kubectl get pods`) and see an error similar to this:

```
The connection to the server <ip_address>:6443 was refused - did you specify the right host or port?
```

### Cause

This is the most common issue after a `kubeadm` installation. The deployment script must be run with `sudo`. When it creates the Kubernetes cluster, the necessary configuration file (`admin.conf`) is placed in the `root` user's home directory (`/etc/kubernetes/`).

Your regular, non-root user does not have this configuration, so `kubectl` does not know how to connect to the new cluster.

### Solution

You need to copy the configuration file to your own user's home directory. Run the following three commands from your server's terminal:

```bash
# 1. Create the .kube directory in your home folder if it doesn't exist
mkdir -p $HOME/.kube

# 2. Copy the cluster configuration file from the root-owned location
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# 3. Change the ownership of the file to your own user
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

After running these commands, your `kubectl` commands will work correctly.

---
## Issue 2: Script fails with "apt lock" or "dpkg lock" error

### Symptoms
During the initial run of a deployment script on a fresh Ubuntu server, the script fails with an error message like:

```
E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process XXXX (unattended-upgr)
```

### Cause
Fresh Ubuntu servers often run an automatic update process (`unattended-upgrades`) in the background shortly after booting. This process locks the `apt` package manager, preventing any other software from being installed. If the deployment script tries to install dependencies at the same time, it will fail.

### Solution
This issue has been **fixed in the latest version of the deployment scripts**. The scripts now include a "wait loop" that automatically detects if the package manager is locked and patiently waits for it to become free before proceeding.

If you encounter this error, please ensure you have the latest version of the code.

---
## Issue 3: `kubeadm init` fails with "preflight" errors

### Symptoms
The on-premise deployment script fails during the `kubeadm init` phase with errors like:
```
[ERROR CRI]: container runtime is not running...
[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: ... does not exist
```
### Cause
The server's kernel and container runtime (Docker/containerd) are not correctly configured for Kubernetes before `kubeadm` is run.

### Solution
This issue has been **fixed in the latest version of the deployment scripts**. The scripts now include a "Prepare System for Kubernetes" step that automatically loads the required kernel modules, sets the necessary `sysctl` parameters, and resets the `containerd` configuration to ensure all preflight checks pass.

If you encounter this error, please ensure you have the latest version of the code.

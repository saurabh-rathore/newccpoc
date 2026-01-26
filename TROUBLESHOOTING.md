# Troubleshooting Guide

This guide provides solutions to common errors and issues you may encounter during the deployment and operation of the AI Voice Call Center.

---

## Issue 1: `kubectl` commands fail with "connection refused" (as a regular user)

### Symptoms

After running an on-premise script, you try to run `kubectl get pods` as a regular user and see:
```
The connection to the server <ip_address>:6443 was refused - did you specify the right host or port?
```

### Cause

The deployment script was run with `sudo`, so the Kubernetes configuration file was created for the `root` user only. Your regular user does not have access.

### Solution

Run these three commands to copy the configuration to your home directory:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Issue 2: `kubectl` commands fail with "connection refused" (even as root)

### Symptoms

You are running `kubectl` as the `root` user (or using `sudo kubectl`), but you still see the "connection refused" error. This is a more serious issue.

### Cause

This error means that the **Kubernetes API server itself is not running**. The core "brain" of your Kubernetes cluster has either crashed or failed to start. This is most often caused by insufficient system resources (CPU or RAM) on the server, especially on smaller cloud instances.

### Solution: Diagnose the Control Plane

You need to check the status of the main Kubernetes agent, the `kubelet`.

**Step 1: Check the `kubelet` service status**
```bash
sudo systemctl status kubelet
```
Look for `Active: active (running)`. If it is `inactive` or `failed`, the cluster has failed to start.

**Step 2: View the `kubelet` logs**
This is the most important diagnostic step. It will show you the exact error messages.
```bash
sudo journalctl -u kubelet -f
```
Look for repeating error messages. Common errors include:
-   "failed to pull image": The cluster is trying to download a core component and failing.
-   "memory pressure": Your server does not have enough RAM.
-   "CRI": There is a problem with the container runtime (Docker/containerd).

**Step 3: Check the core container status directly**
This command bypasses `kubectl` to see what Kubernetes is trying to do.
```bash
sudo crictl ps -a
```
In a healthy cluster, you should see containers with names like `kube-apiserver`, `kube-scheduler`, `etcd`, etc., in the `Running` state. If they are `Exited` or missing, it confirms the control plane is failing.

**Step 4: Check System Resource Requirements**
The Kubernetes control plane itself requires a certain amount of resources. For the on-premise scripts, a machine with at least **2 vCPUs and 8 GB of RAM** is recommended for the cluster to be stable, even for the CPU-only testing version. A "medium" instance with less than 8 GB of RAM may not be sufficient.

---

## Issue 3: Script fails with "apt lock" or "dpkg lock" error

### Symptoms
The script fails with an error like `E: Could not get lock /var/lib/dpkg/lock-frontend`.

### Cause
A background process (`unattended-upgrades`) on the fresh Ubuntu server has locked the package manager.

### Solution
This issue has been **fixed in the latest version of the deployment scripts**. If you see this, please ensure you have the latest version of the code.

---

## Issue 4: `kubeadm init` fails with "preflight" errors

### Symptoms
The script fails with errors like `[ERROR CRI]` or `[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]`.

### Cause
The server's kernel or container runtime is not correctly configured for Kubernetes.

### Solution
This issue has been **fixed in the latest version of the deployment scripts**. If you see this, please ensure you have the latest version of the code.

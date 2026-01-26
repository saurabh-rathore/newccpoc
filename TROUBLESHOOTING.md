# Troubleshooting Guide

This guide provides solutions to common errors and issues you may encounter during the deployment and operation of the AI Voice Call Center.

---

## Issue 1: `kubectl` commands fail with "connection refused" (as a regular user)
... (content remains the same)

---

## Issue 2: `kubectl` commands fail with "connection refused" (even as root)
... (content remains the same)

---

## Issue 3: `kubeadm init` fails with "CNI plugin not initialised" or "dockershim" errors

### Symptoms

The on-premise deployment script fails during or after the `kubeadm init` phase.
-   When running `sudo crictl ps -a`, you see errors like: `dial unix /var/run/dockershim.sock: connect: no such file or directory`.
-   The `kubelet` logs (`sudo journalctl -u kubelet`) contain messages like `cni plugin not initialised`.

### Cause

This is a critical misconfiguration between Kubernetes and the container runtime. Modern versions of Kubernetes (1.24+) have removed the old `dockershim` component and now communicate with container runtimes (like `containerd`) directly. The error indicates that the `kubelet` is still trying to find the old, non-existent `dockershim` socket. This prevents the CNI (Container Network Interface) from starting, which means pods cannot get IP addresses, and the cluster fails to initialize.

### Solution

This issue has been **fixed in the latest version of the deployment scripts**. The scripts now perform two key actions to prevent this:
1.  **Reset `containerd` config:** The scripts now ensure any old, incompatible configuration for `containerd` is removed.
2.  **Use an explicit `kubeadm` config:** The scripts now generate and use a `kubeadm-config.yaml` file that explicitly tells the `kubelet` to use the correct, modern `containerd` socket (`unix:///run/containerd/containerd.sock`).

If you encounter this error, please ensure you have the latest version of the code.

---

## Issue 4: Script fails with "apt lock" or "dpkg lock" error
... (content remains the same)

---

## Issue 5: `kubeadm init` fails with "preflight" errors
... (content remains the same)

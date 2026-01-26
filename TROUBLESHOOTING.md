# Troubleshooting Guide

This guide provides solutions to common errors and issues you may encounter during the deployment and operation of the AI Voice Call Center.

---

## How to Recover from a Failed On-Premise Deployment

**IMPORTANT:** If one of the on-premise deployment scripts (`deploy-on-prem.sh` or `deploy-on-prem-cpu.sh`) fails for any reason, you **must reset the cluster state** before running the script again.

Running `kubeadm init` on a partially configured system will lead to further errors.

### Recovery Command

Before you re-run a failed deployment script, connect to your server and run the following command. This will safely undo all the changes made by the previous `kubeadm init` attempt.

```bash
sudo kubeadm reset -f
```
After the reset command finishes, you can safely re-run the deployment script.

---

## Issue 1: `kubectl` commands fail with "connection refused" (as a regular user)
... (content remains the same)

---

## Issue 2: `kubectl` commands fail with "connection refused" (even as root)
... (content remains the same)

---

## Issue 3: `kubeadm init` fails with "CNI plugin not initialised" or "dockershim" errors
... (content remains the same)

---

## Issue 4: Script fails with "apt lock" or "dpkg lock" error
... (content remains the same)

---

## Issue 5: `kubeadm init` fails with "preflight" errors
... (content remains the same)

# Performance, Capacity, and Scaling Guide

This document provides a detailed analysis of the AI Voice Call Center's call handling capacity. The performance of this system is fundamentally tied to the deployment architecture you choose.

We will analyze two scenarios:
1.  **Single-Node Deployment:** Using the `docker-compose` setup on a single recommended EC2 instance (`g4dn.xlarge`).
2.  **Scalable Kubernetes Deployment:** Using the provided Kubernetes manifests on an Amazon EKS cluster.

---

## Identifying the System's Primary Bottleneck

In a traditional telecom system, the bottleneck is often the call handling software (like Asterisk) or network throughput. In this AI-powered system, that is not the case.

The primary bottleneck for concurrent call capacity is **GPU VRAM and processing power.**

Each active phone call requires a "slice" of the GPU's resources to run three simultaneous AI tasks:
1.  **Speech-to-Text (Whisper):** Continuously transcribing the caller's audio.
2.  **Language Model (Mixtral):** Generating a response once the transcription is ready.
3.  **Text-to-Speech (Coqui):** Synthesizing the LLM's response into audio.

A single GPU has a finite amount of memory (VRAM) and processing cores. The total number of concurrent calls the system can handle is determined by how many of these AI pipelines can run simultaneously on the available GPU hardware.

---

## Scenario 1: Single-Node EC2 Deployment Capacity

This analysis assumes you are using the recommended `g4dn.xlarge` EC2 instance, which has an NVIDIA T4 GPU with 16 GB of VRAM.

### Assumptions:
*   **Instance:** `g4dn.xlarge` (1 NVIDIA T4 GPU, 16 GB VRAM).
*   **Models:** Quantized Mixtral (GPTQ), Whisper (distilled), Coqui TTS.
*   **Average Call Duration:** 3 minutes.

### Capacity Estimation:

1.  **VRAM Allocation:**
    *   LLM (Mixtral) loaded into memory: ~8 GB
    *   STT (Whisper) model: ~1.5 GB
    *   TTS (Coqui) model: ~1 GB
    *   Embedding model: ~0.5 GB
    *   **Total VRAM for loaded models:** **~11 GB**
    *   *Remaining VRAM for active processing:* **~5 GB**

2.  **Concurrent Call Estimation:**
    *   Each active call's STT/TTS inference will consume a portion of the remaining VRAM. Based on the model sizes and processing overhead, a single T4 GPU can safely handle **2 to 4 simultaneous AI inference pipelines.**
    *   Let's use a conservative average of **3 concurrent calls**.

### Estimated Call Volume (Single `g4dn.xlarge`):

*   **Per Second:** The system is not designed for sub-second call resolution. The key metric is concurrency.
*   **Per Minute:** If the system can handle 3 calls at once, and each call lasts an average of 3 minutes, then the system completes a cycle of 3 calls every 3 minutes.
    *   **Capacity: ~1 call per minute.**
*   **Per Hour:**
    *   `1 call/minute * 60 minutes =` **~60 calls per hour.**
*   **Per Day:**
    *   Assuming a 10-hour peak business day: `60 calls/hour * 10 hours =` **~600 calls per day.**
    *   Over a full 24-hour period: `60 calls/hour * 24 hours =` **~1,440 calls per day.**

**Conclusion for Single-Node:** A single-node deployment is suitable for low-volume applications, internal testing, or as a proof-of-concept. It can handle the user's initial requirement of "1000+ calls per day" but without significant headroom.

---

## Scenario 2: Scalable Kubernetes Deployment Capacity

The Kubernetes architecture was specifically designed to overcome the single-node bottleneck. The system's capacity is no longer limited by a single GPU; it is limited only by the number of GPU nodes you add to your cluster.

The principle is **horizontal scaling.**

### Scaling Mechanism:
*   The Kubernetes `Deployment` for the AI services is configured to run on nodes with the `nvidia.com/gpu: "true"` label.
*   The Kubernetes scheduler will automatically distribute the AI service pods across all available GPU nodes.
*   The stateless services (like the AI Voice Gateway and Asterisk) can be scaled independently on cheaper, CPU-only nodes.

### Estimated Call Volume (Kubernetes Cluster):

Each `g4dn.xlarge` node you add to your EKS `gpu-workers` node group increases the total concurrent call capacity of the cluster by **~3 calls.**

| Number of GPU Nodes (`g4dn.xlarge`) | Estimated Concurrent Calls | Estimated Calls per Hour | Estimated Calls per Day (10hr Peak) |
| :---------------------------------- | :------------------------- | :----------------------- | :---------------------------------- |
| 1                                   | ~3                         | ~60                      | ~600                                |
| 5                                   | ~15                        | ~300                     | ~3,000                              |
| 10                                  | ~30                        | ~600                     | ~6,000                              |
| 20                                  | ~60                        | ~1,200                   | ~12,000                             |

**Conclusion for Kubernetes:** The architecture is built to scale linearly. You can meet virtually any call volume demand by adding more GPU nodes to your EKS cluster. This is the required architecture for a high-volume, production-ready solution.

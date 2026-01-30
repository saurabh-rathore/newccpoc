# Use an NVIDIA CUDA runtime as a parent image for GPU support
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

# Set non-interactive frontend for package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install Python, Pip, and Git
RUN apt-get update && apt-get install -y \
    python3.9 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# --- Model Caching ---
# Download the model before installing requirements to leverage Docker layer caching.
ARG LLM_MODEL="TheBloke/Mixtral-8x7B-Instruct-v0.1-GPTQ"
RUN pip3 install huggingface-hub && \
    hf download ${LLM_MODEL} --local-dir /models/${LLM_MODEL} --local-dir-use-symlinks False

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies
# Using --extra-index-url for auto-gptq as it may have specific dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the rest of the application's code into the container
COPY . .

# Expose the port the app runs on
EXPOSE 8002

# Command to run the application
ENV LLM_MODEL=${LLM_MODEL}
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002"]

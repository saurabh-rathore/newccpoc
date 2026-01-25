# Use an NVIDIA CUDA runtime as a parent image for GPU support
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

# Set non-interactive frontend for package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install Python, Pip, Git, and necessary build tools
RUN apt-get update && apt-get install -y \
    python3.9 \
    python3-pip \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# --- Model Caching ---
# Download the model before installing requirements to leverage Docker layer caching.
# This ensures the model is not re-downloaded unless the model name changes.
ARG WHISPER_MODEL="distil-whisper/distil-small.en"
RUN pip3 install huggingface-hub && \
    huggingface-cli download ${WHISPER_MODEL} --local-dir /models/${WHISPER_MODEL} --local-dir-use-symlinks False

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the rest of the application's code into the container
COPY . .

# Expose the port the app runs on
EXPOSE 8001

# Command to run the application
# We pass the model name as an environment variable
ENV WHISPER_MODEL=${WHISPER_MODEL}
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]

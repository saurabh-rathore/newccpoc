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
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# --- Model Caching ---
# Download the TTS model before installing requirements to leverage Docker layer caching.
ARG TTS_MODEL="tts_models/en/ljspeech/tacotron2-DDC"
# This command is a bit of a workaround to download the model files using the tts library itself
RUN pip3 install TTS && \
    python3 -c "from TTS.utils.manage import ModelManager; mm = ModelManager(); mm.download_model('${TTS_MODEL}')"

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the rest of the application's code into the container
COPY . .

# Expose the port the app runs on
EXPOSE 8003

# Command to run the application
ENV TTS_MODEL=${TTS_MODEL}
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]

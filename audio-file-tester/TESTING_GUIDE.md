# Testing Guide: Audio File Input

This guide provides step-by-step instructions on how to test the core AI pipeline using a sample audio file. This method allows you to verify the Speech-to-Text, Language Model, and Text-to-Speech services without needing to set up a live phone call.

### Step 1: Start the Testing Environment

First, you need to launch the dedicated Docker Compose environment for this test.

1.  Navigate to the `audio-file-tester` directory:
    ```bash
    cd audio-file-tester
    ```

2.  Make the deployment script executable:
    ```bash
    chmod +x deploy-audio-test.sh
    ```

3.  Run the deployment script. This will build the necessary Docker images and start all the required services (this may take several minutes on the first run).
    ```bash
    ./deploy-audio-test.sh
    ```

    Once the script is finished, all services will be running in the background.

### Step 2: Send the Sample Audio File for Processing

We will use the `curl` command to send the included `sample_query.wav` file to the Audio Gateway's API endpoint.

1.  Ensure you are still in the `audio-file-tester` directory.

2.  Execute the following `curl` command. This command sends a `POST` request, uploads the audio file, and saves the audio response from the server into a new file named `response.wav`.

    ```bash
    curl -X POST \
      -F "audio_file=@sample_query.wav;type=audio/wav" \
      http://localhost:8000/process-voice-note \
      -o response.wav
    ```

3.  If the command is successful, you will see a new file named `response.wav` in the directory. This is the AI's spoken response. You can play this file using any standard audio player.

### Step 3: View Logs (Optional)

If you want to see the real-time processing logs from the services (e.g., the transcription from the STT service or the response from the LLM), you can view the logs of the containers.

```bash
# View the logs of the main audio-gateway
docker compose -f docker-compose.audio-test.yml logs -f audio-gateway

# View the logs of all services
docker compose -f docker-compose.audio-test.yml logs -f
```

### Step 4: Clean Up the Environment

Once you are finished testing, you can stop and remove all the running containers with a single command.

1.  Ensure you are still in the `audio-file-tester` directory.

2.  Run the following command:
    ```bash
    docker compose -f docker-compose.audio-test.yml down
    ```

This will stop and remove the containers, freeing up system resources.

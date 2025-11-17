/**
 * AudioRecorder Hook
 *
 * Handles browser-based audio recording using the MediaRecorder API.
 * Captures audio from the user's microphone and provides a blob for upload.
 *
 * Events listened to from server:
 * - start-audio-recording: Begin recording
 * - stop-audio-recording: Stop recording and prepare blob
 * - cancel-audio-recording: Cancel recording and cleanup
 * - request-audio-data: Send audio data to server for processing
 *
 * Events sent to server:
 * - update_duration: Periodic updates of recording duration (every second)
 * - recording_complete: Fires when recording stops with blob URL and sets audio player
 * - audio_data: Sends base64-encoded audio data
 * - recording_error: Sends error messages
 */

const AudioRecorder = {
  mounted() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.stream = null;
    this.timerInterval = null;
    this.startTime = null;
    this.audioBlob = null;
    this.selectedDeviceId = null;

    // Enumerate available audio input devices
    this.enumerateDevices();

    // Listen for server events
    this.handleEvent("start-audio-recording", (payload) => this.startRecording(payload.device_id));
    this.handleEvent("stop-audio-recording", () => this.stopRecording());
    this.handleEvent("cancel-audio-recording", () => this.cleanup());
    this.handleEvent("request-audio-data", () => this.sendAudioData());
  },

  destroyed() {
    this.cleanup();
  },

  async enumerateDevices() {
    try {
      // Request initial permission to enumerate devices with labels
      const tempStream = await navigator.mediaDevices.getUserMedia({ audio: true });

      // Get list of all media devices
      const devices = await navigator.mediaDevices.enumerateDevices();

      // Stop the temporary stream immediately
      tempStream.getTracks().forEach(track => track.stop());

      // Filter to audio input devices only
      const audioInputs = devices
        .filter(device => device.kind === 'audioinput')
        .map(device => ({
          deviceId: device.deviceId,
          label: device.label || `Microphone ${device.deviceId.substring(0, 8)}`,
          kind: device.kind
        }));

      // Send to LiveView component
      if (audioInputs.length > 0) {
        this.pushEvent("devices_enumerated", { devices: audioInputs });
        this.selectedDeviceId = audioInputs[0].deviceId; // Default to first device
      }

      console.log("Available audio inputs:", audioInputs);
    } catch (error) {
      console.error("Failed to enumerate devices:", error);
    }
  },

  async startRecording(deviceId) {
    try {
      // Use selected device or default
      const actualDeviceId = deviceId || this.selectedDeviceId;

      // Request microphone access - IMPORTANT: Explicitly request audio INPUT
      const constraints = {
        audio: actualDeviceId ? {
          deviceId: { exact: actualDeviceId },
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        } : {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      };

      console.log("Starting recording with constraints:", constraints);
      this.stream = await navigator.mediaDevices.getUserMedia(constraints);

      // Log the actual track being used
      const audioTrack = this.stream.getAudioTracks()[0];
      console.log("Recording from:", audioTrack.label, "Settings:", audioTrack.getSettings());

      // Determine the best supported MIME type
      const mimeType = this.getSupportedMimeType();

      if (!mimeType) {
        console.error("No supported audio MIME type found");
        this.pushEvent("recording_error", { error: "Unsupported browser" });
        return;
      }

      // Create MediaRecorder
      this.mediaRecorder = new MediaRecorder(this.stream, { mimeType });
      this.audioChunks = [];

      // Handle data availability
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      };

      // Handle recording stop
      this.mediaRecorder.onstop = () => {
        this.handleRecordingComplete();
      };

      // Handle errors
      this.mediaRecorder.onerror = (event) => {
        console.error("MediaRecorder error:", event.error);
        this.pushEvent("recording_error", { error: event.error.message });
        this.cleanup();
      };

      // Start recording
      this.mediaRecorder.start();
      this.startTime = Date.now();

      // Start timer to update duration
      this.timerInterval = setInterval(() => {
        const duration = Math.floor((Date.now() - this.startTime) / 1000);
        this.pushEvent("update_duration", { duration });
      }, 1000);

      console.log("Recording started with MIME type:", mimeType);

    } catch (error) {
      console.error("Failed to start recording:", error);

      let errorMessage = "Could not access microphone";
      if (error.name === "NotAllowedError") {
        errorMessage = "Microphone access denied. Please allow microphone access in browser settings.";
      } else if (error.name === "NotFoundError") {
        errorMessage = "No microphone found. Please connect a microphone and try again.";
      }

      this.pushEvent("recording_error", { error: errorMessage });
      this.cleanup();
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop();

      // Stop timer
      if (this.timerInterval) {
        clearInterval(this.timerInterval);
        this.timerInterval = null;
      }

      // Stop all tracks
      if (this.stream) {
        this.stream.getTracks().forEach(track => track.stop());
      }

      console.log("Recording stopped");
    }
  },

  handleRecordingComplete() {
    // Create blob from audio chunks
    this.audioBlob = new Blob(this.audioChunks, {
      type: this.mediaRecorder.mimeType
    });

    // Create a URL for the blob (for playback)
    const blobUrl = URL.createObjectURL(this.audioBlob);

    // Set audio player source for playback preview
    const audioPlayer = document.getElementById('audio-playback');
    if (audioPlayer) {
      audioPlayer.src = blobUrl;
      audioPlayer.load();
    }

    // Store blob for later upload
    window._currentAudioBlob = this.audioBlob;
    window._currentAudioMimeType = this.mediaRecorder.mimeType;

    // Notify the LiveView component
    this.pushEvent("recording_complete", {
      blob_url: blobUrl,
      size: this.audioBlob.size,
      mime_type: this.mediaRecorder.mimeType
    });

    console.log("Recording complete:", {
      size: this.audioBlob.size,
      mimeType: this.mediaRecorder.mimeType,
      duration: Math.floor((Date.now() - this.startTime) / 1000)
    });
  },

  async sendAudioData() {
    if (!this.audioBlob) {
      console.error("No audio blob available");
      this.pushEvent("recording_error", { error: "No audio data available" });
      return;
    }

    try {
      // Convert blob to base64
      const reader = new FileReader();

      reader.onloadend = () => {
        // Extract base64 data (remove data:audio/...;base64, prefix)
        const base64Data = reader.result.split(',')[1];

        // Send to LiveView
        this.pushEvent("audio_data", {
          data: base64Data,
          mime_type: this.audioBlob.type,
          size: this.audioBlob.size
        });

        console.log("Audio data sent to server:", {
          size: this.audioBlob.size,
          mimeType: this.audioBlob.type
        });
      };

      reader.onerror = () => {
        console.error("Failed to read audio blob");
        this.pushEvent("recording_error", { error: "Failed to read audio data" });
      };

      reader.readAsDataURL(this.audioBlob);
    } catch (error) {
      console.error("Error sending audio data:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  getSupportedMimeType() {
    const types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
      'audio/mp4',
      'audio/mpeg'
    ];

    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }

    return null;
  },

  cleanup() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }

    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }

    if (this.mediaRecorder) {
      this.mediaRecorder = null;
    }

    // Clear audio player
    const audioPlayer = document.getElementById('audio-playback');
    if (audioPlayer && audioPlayer.src) {
      URL.revokeObjectURL(audioPlayer.src);
      audioPlayer.src = '';
      audioPlayer.load();
    }

    this.audioChunks = [];
    this.startTime = null;
    this.audioBlob = null;
  }
};

export default AudioRecorder;

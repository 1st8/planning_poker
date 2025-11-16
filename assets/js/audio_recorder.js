/**
 * AudioRecorder Hook
 *
 * Handles browser-based audio recording using the MediaRecorder API.
 * Captures audio from the user's microphone and provides a blob for upload.
 *
 * Events listened to from server:
 * - start-audio-recording: Begin recording
 * - stop-audio-recording: Stop recording and prepare blob
 *
 * Events sent to server:
 * - update_duration: Periodic updates of recording duration (every second)
 * - recording_complete: Fires when recording stops with blob URL
 */

const AudioRecorder = {
  mounted() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.stream = null;
    this.timerInterval = null;
    this.startTime = null;
    this.audioBlob = null;

    // Listen for server events
    this.handleEvent("start-audio-recording", () => this.startRecording());
    this.handleEvent("stop-audio-recording", () => this.stopRecording());
  },

  destroyed() {
    this.cleanup();
  },

  async startRecording() {
    try {
      // Request microphone access
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });

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

    // Create a URL for the blob (for potential playback)
    const blobUrl = URL.createObjectURL(this.audioBlob);

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

    this.audioChunks = [];
    this.startTime = null;
  }
};

export default AudioRecorder;

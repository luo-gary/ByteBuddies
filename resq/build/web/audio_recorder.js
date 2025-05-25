// Global object to store recorder state
window.flutterWebRecorder = {
    mediaRecorder: null,
    audioData: null,
    error: null,
    chunks: []
};

// Start recording function
window.startRecording = async function() {
    try {
        // Reset state
        window.flutterWebRecorder.chunks = [];
        window.flutterWebRecorder.audioData = null;
        window.flutterWebRecorder.error = null;

        // Request microphone access
        const stream = await navigator.mediaDevices.getUserMedia({ 
            audio: {
                channelCount: 1,
                sampleRate: 44100,
                echoCancellation: true,
                noiseSuppression: true
            } 
        });
        
        // Create MediaRecorder instance with WAV format
        const mediaRecorder = new MediaRecorder(stream, {
            mimeType: 'audio/webm;codecs=opus'
        });
        window.flutterWebRecorder.mediaRecorder = mediaRecorder;

        // Set up data handling
        mediaRecorder.ondataavailable = (e) => {
            if (e.data.size > 0) {
                window.flutterWebRecorder.chunks.push(e.data);
            }
        };

        // Handle recording stop
        mediaRecorder.onstop = async () => {
            try {
                const blob = new Blob(window.flutterWebRecorder.chunks, { type: 'audio/webm' });
                const reader = new FileReader();
                
                reader.onloadend = () => {
                    window.flutterWebRecorder.audioData = reader.result;
                };
                
                reader.onerror = (error) => {
                    console.error('Error reading audio data:', error);
                    window.flutterWebRecorder.error = 'Failed to process audio data';
                };
                
                reader.readAsDataURL(blob);
                
                // Stop all tracks
                stream.getTracks().forEach(track => track.stop());
            } catch (error) {
                console.error('Error processing audio:', error);
                window.flutterWebRecorder.error = 'Failed to process audio recording';
            }
        };

        // Start recording with 10ms timeslice for more frequent ondataavailable events
        mediaRecorder.start(10);
    } catch (error) {
        console.error('Error starting recording:', error);
        window.flutterWebRecorder.error = error.message || 'Failed to start recording';
    }
};

// Stop recording function
window.stopRecording = function() {
    try {
        if (window.flutterWebRecorder.mediaRecorder && 
            window.flutterWebRecorder.mediaRecorder.state !== 'inactive') {
            window.flutterWebRecorder.mediaRecorder.stop();
        }
    } catch (error) {
        console.error('Error stopping recording:', error);
        window.flutterWebRecorder.error = error.message || 'Failed to stop recording';
    }
}; 
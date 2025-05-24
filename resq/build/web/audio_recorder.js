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
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
        // Create MediaRecorder instance
        const mediaRecorder = new MediaRecorder(stream);
        window.flutterWebRecorder.mediaRecorder = mediaRecorder;

        // Set up data handling
        mediaRecorder.ondataavailable = (e) => {
            if (e.data.size > 0) {
                window.flutterWebRecorder.chunks.push(e.data);
            }
        };

        // Handle recording stop
        mediaRecorder.onstop = () => {
            const blob = new Blob(window.flutterWebRecorder.chunks, { type: 'audio/wav' });
            const reader = new FileReader();
            reader.onloadend = () => {
                window.flutterWebRecorder.audioData = reader.result;
            };
            reader.readAsDataURL(blob);
            
            // Stop all tracks
            stream.getTracks().forEach(track => track.stop());
        };

        // Start recording
        mediaRecorder.start();
    } catch (error) {
        console.error('Error starting recording:', error);
        window.flutterWebRecorder.error = error.message;
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
        window.flutterWebRecorder.error = error.message;
    }
}; 
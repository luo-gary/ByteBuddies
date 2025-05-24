# ResQ Link

A peer-to-peer emergency communicator for natural disasters that works without internet using iPhone hotspot broadcasting, AI environment analysis, and local sharing.

## Features

- **Multimedia SOS Capture**
  - Take photos of emergency situations
  - Record voice messages
  - Automatic GPS location tagging
  - Works offline

- **Offline Communication**
  - Peer-to-peer data sharing using MultipeerConnectivity
  - Devices act as relays to extend reach
  - Automatic discovery of nearby devices

- **AI-Powered Analysis**
  - On-device image classification for situation assessment
  - Audio keyword detection
  - Severity estimation
  - People detection

- **Emergency Guidance**
  - Real-time survival tips based on detected situation
  - Offline-first design
  - Clear, actionable instructions

## Setup

1. Install Flutter:
   ```bash
   brew install flutter
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/resq.git
   cd resq
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Download TensorFlow Lite models:
   - Create `assets/models` directory
   - Download and place the following models:
     - `image_classifier.tflite`
     - `audio_classifier.tflite`

5. Run the app:
   ```bash
   flutter run
   ```

## Technical Architecture

### Core Components

1. **Emergency Capture**
   - Camera integration for photo capture
   - Audio recording system
   - GPS location services
   - Local storage management

2. **P2P Communication**
   - Nearby Connections API integration
   - Device discovery and pairing
   - Data synchronization protocol

3. **AI Analysis**
   - TensorFlow Lite integration
   - Custom image classification model
   - Audio processing pipeline
   - Real-time analysis system

4. **Data Management**
   - Local storage with JSON
   - Queue system for unsent messages
   - Data compression for efficient sharing

### Dependencies

- `camera`: Camera access and photo capture
- `permission_handler`: Permission management
- `record`: Audio recording
- `geolocator`: GPS location services
- `nearby_connections`: P2P communication
- `tflite_flutter`: TensorFlow Lite integration
- `path_provider`: File system access
- `uuid`: Unique identifier generation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- TensorFlow team for TFLite
- All contributors and testers

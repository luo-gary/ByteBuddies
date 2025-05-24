# ResQ

A peer-to-peer emergency communicator for natural disasters, using AI for situation analysis and offline communication.

## Features

- Emergency photo and audio capture
- AI-powered scene analysis
- Offline peer-to-peer communication
- Location-based emergency reporting
- Emergency services dashboard
- Situation-specific safety tips

## Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Create a `.env` file in the project root with your OpenAI API key:
```
OPENAI_API_KEY=your_api_key_here
```

3. Run the app:
```bash
flutter run
```

## Environment Variables

The app requires the following environment variables in a `.env` file:

- `OPENAI_API_KEY`: Your OpenAI API key for image and audio analysis

## Development

- The app uses Flutter's latest stable version
- OpenAI's GPT-4 Vision for image analysis
- Whisper for audio transcription
- Material 3 design system
- Offline-first architecture

## Security

- API keys are stored in `.env` (not in version control)
- Location data is optional and user-controlled
- P2P communication is local-only
- No data is stored on external servers

## License

MIT License - See LICENSE file for details

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
   - OpenAI GPT-4 Vision for image analysis
   - OpenAI Whisper for audio transcription
   - Real-time situation assessment
   - Safety tip generation based on context

4. **Data Management**
   - Local storage with JSON
   - Queue system for unsent messages
   - Data compression for efficient sharing
   - Secure API key handling

### Dependencies

- `camera`: Camera access and photo capture
- `permission_handler`: Permission management
- `record`: Audio recording
- `geolocator`: GPS location services
- `nearby_connections`: P2P communication
- `flutter_dotenv`: Environment variable management
- `http`: API communication
- `path_provider`: File system access
- `uuid`: Unique identifier generation
- `intl`: Date and time formatting

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Acknowledgments

- Flutter team for the amazing framework
- OpenAI team for GPT-4 Vision and Whisper
- All contributors and testers

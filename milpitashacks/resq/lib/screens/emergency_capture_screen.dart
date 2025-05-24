import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/emergency_data.dart';
import '../services/ai_service.dart';
import '../services/p2p_service.dart';
import '../screens/emergency_result_screen.dart';

class EmergencyCaptureScreen extends StatefulWidget {
  const EmergencyCaptureScreen({super.key});

  @override
  State<EmergencyCaptureScreen> createState() => _EmergencyCaptureScreenState();
}

class _EmergencyCaptureScreenState extends State<EmergencyCaptureScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _photoPath;
  String? _audioPath;
  Position? _currentPosition;
  final _audioRecorder = AudioRecorder();
  final _aiService = AIService();
  final _p2pService = P2PService();
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _requestPermissions();
    _getCurrentLocation();
    _startP2PServices();
  }

  Future<void> _startP2PServices() async {
    await _p2pService.startAdvertising();
    await _p2pService.startDiscovery();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.location.request();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (!_cameraController.value.isInitialized) return;

    try {
      final XFile photo = await _cameraController.takePicture();
      setState(() {
        _photoPath = photo.path;
      });
      _analyzeScene();
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _audioPath = path;
        _isRecording = false;
      });
      _analyzeScene();
    } else {
      await _startRecording();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      String filePath = await getApplicationDocumentsDirectory()
          .then((value) => '${value.path}/${_generateRandomId()}.wav');

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: filePath,
      );
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _analyzeScene() async {
    if (_photoPath == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final analysis = await _aiService.analyzeEmergencyScene(
        imagePath: _photoPath!,
        audioPath: _audioPath,
      );

      setState(() {
        _analysis = analysis;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Error analyzing scene: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _sendEmergencyData() async {
    if (_currentPosition == null || _photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a photo and ensure location access is granted'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final emergencyData = EmergencyData(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        photoPath: _photoPath,
        audioPath: _audioPath,
      );

      await EmergencyData.saveEmergencyData(emergencyData);

      // Broadcast to nearby devices
      await _p2pService.broadcastEmergencyData(emergencyData);

      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
      });

      // Navigate to result screen instead of showing dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyResultScreen(
            emergencyData: emergencyData,
            analysis: _analysis ?? {
              'detectedSituation': 'Emergency situation detected',
              'severity': 'Medium',
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error sending emergency data: $e');
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending emergency data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(
      10,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _audioRecorder.dispose();
    _aiService.dispose();
    _p2pService.stopAllEndpoints();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CameraPreview(_cameraController),
                  if (_currentPosition != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                              '${_currentPosition!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            if (_analysis != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Detected: ${_analysis!['detectedSituation']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Severity: ${_analysis!['severity']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _isProcessing ? null : _capturePhoto,
                    icon: const Icon(
                      Icons.camera,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  IconButton(
                    onPressed: _isProcessing ? null : _toggleRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording ? Colors.red : Colors.white,
                      size: 32,
                    ),
                  ),
                  IconButton(
                    onPressed: (_photoPath != null && !_isProcessing) ? _sendEmergencyData : null,
                    icon: Icon(
                      Icons.send,
                      color: (_photoPath != null && !_isProcessing) ? Colors.red : Colors.grey,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
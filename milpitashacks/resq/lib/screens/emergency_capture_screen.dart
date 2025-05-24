import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/emergency_data.dart';
import '../services/openai_service.dart';
import '../services/p2p_service.dart';
import '../screens/emergency_result_screen.dart';

class EmergencyCaptureScreen extends StatefulWidget {
  const EmergencyCaptureScreen({super.key});

  @override
  State<EmergencyCaptureScreen> createState() => _EmergencyCaptureScreenState();
}

class _EmergencyCaptureScreenState extends State<EmergencyCaptureScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _photoPath;
  String? _audioPath;
  Position? _currentPosition;
  final _audioRecorder = AudioRecorder();
  final _openAIService = OpenAIService();
  final _p2pService = P2PService();
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getCurrentLocation();
    _startP2PServices();
  }

  Future<void> _requestPermissions() async {
    try {
      // Request camera permission first
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        // Show settings dialog if permission is permanently denied
        if (cameraStatus.isPermanentlyDenied) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Camera Permission Required'),
              content: const Text(
                'Camera access is required to capture emergency photos. Please enable it in settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          return;
        }
        throw Exception('Camera permission is required');
      }

      // Only initialize camera after permission is granted
      await _initializeCamera();

      // Request other permissions
      final micStatus = await Permission.microphone.request();
      final locationStatus = await Permission.location.request();
      final bluetoothStatus = await Permission.bluetooth.request();
      final bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();

      if (!micStatus.isGranted || 
          !locationStatus.isGranted ||
          !bluetoothStatus.isGranted || 
          !bluetoothAdvertiseStatus.isGranted ||
          !bluetoothConnectStatus.isGranted ||
          !bluetoothScanStatus.isGranted) {
        throw Exception('Additional permissions are required for full functionality');
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission error: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () async {
              await openAppSettings();
            },
          ),
        ),
      );
    }
  }

  Future<void> _startP2PServices() async {
    try {
      // Ensure all permissions are granted before starting P2P services
      await _requestPermissions();
      
      // Initialize P2P services
      await Future.wait([
        _p2pService.startAdvertising(),
        _p2pService.startDiscovery(),
      ]);
    } catch (e) {
      debugPrint('Error starting P2P services: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('P2P service error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _startP2PServices,
          ),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        final shouldEnable = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Location services are disabled. Enable location services to help emergency responders find you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context, true);
                  await Geolocator.openLocationSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enable Location'),
              ),
            ],
          ),
        ) ?? false;

        if (!shouldEnable) return;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Show dialog explaining why we need location
        if (!mounted) return;
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Access Needed'),
            content: const Text(
              'Your location helps emergency responders find you quickly. '
              'Without location access, we can still send your emergency alert, '
              'but responders won\'t know where to find you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Don\'t Allow'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Allow Location'),
              ),
            ],
          ),
        ) ?? false;

        if (shouldRequest) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            return; // User denied after explanation
          }
        } else {
          return; // User doesn't want to grant permission
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Show dialog to open settings
        if (!mounted) return;
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Access Required'),
            content: const Text(
              'Location access has been permanently denied. '
              'Please enable it in settings to help emergency responders find you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ?? false;

        if (shouldOpenSettings) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      // Get location if permission is granted
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Show error to user
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Get cameras first to check if hardware is available
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cameras available on this device'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Initialize camera controller
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController?.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (!mounted) return;
      
      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error initializing camera. Please check permissions and try again.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _initializeCamera,
          ),
        ),
      );
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
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
      final analysis = await _openAIService.analyzeEmergencyScene(
        imagePath: _photoPath!,
        audioPath: _audioPath,
      );

      setState(() {
        _analysis = analysis;
        _isProcessing = false;
      });

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scene analysis completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error analyzing scene: $e');
      setState(() {
        _isProcessing = false;
        _analysis = {
          'detectedSituation': 'Emergency Situation',
          'severity': 'Unknown',
          'description': 'Unable to analyze the situation. Please proceed with caution.',
        };
      });

      // Show error message to user
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing scene: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _analyzeScene,
          ),
        ),
      );
    }
  }

  Future<void> _sendEmergencyData() async {
    if (_photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a photo first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // If location is null, create a position with default values
      final position = _currentPosition ?? Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      final emergencyData = EmergencyData(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        photoPath: _photoPath,
        audioPath: _audioPath,
      );

      await EmergencyData.saveEmergencyData(emergencyData);

      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
      });

      // Navigate to result screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyResultScreen(
            emergencyData: emergencyData,
            analysis: _analysis ?? {
              'detectedSituation': 'Emergency situation detected',
              'severity': 'Medium',
              'description': 'Emergency situation reported',
              'audioKeywords': <String>[],
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
    _cameraController?.dispose();
    _audioRecorder.dispose();
    _p2pService.stopAllEndpoints();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
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
                  if (_cameraController != null && _cameraController!.value.isInitialized)
                    CameraPreview(_cameraController!),
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
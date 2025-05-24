import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' if (dart.library.html) 'dart:html' as html;
import 'dart:js' as js;
import '../models/emergency_data.dart';
import '../services/openai_service.dart';
import '../services/p2p_service.dart';
import '../screens/emergency_result_screen.dart';
import 'dart:convert';

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
  StreamSubscription? _analysisSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      _setupAnalysisListener();
    });
  }

  void _setupAnalysisListener() {
    _analysisSubscription = _openAIService.analysisStream.listen(
      (updatedAnalysis) {
        if (mounted) {
          setState(() {
            _analysis = updatedAnalysis;
            _isProcessing = updatedAnalysis['isAnalyzing'] ?? false;
          });
          
          // Remove the completion banner
          // if (!updatedAnalysis['isAnalyzing']) {
          //   _showTopBanner('Analysis completed', Colors.green);
          // }
        }
      },
      onError: (error) {
        debugPrint('Error in analysis stream: $error');
        if (mounted) {
          _showTopBanner('Analysis error: $error', Colors.red);
        }
      },
    );
  }

  Future<void> _initializeServices() async {
    if (kIsWeb) {
      // Web-specific initialization
      await _initializeWebCamera();
      await _getCurrentLocation();
    } else {
      // Mobile initialization
      await _requestPermissions();
    }
  }

  Future<void> _initializeWebCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        _showTopBanner('No cameras available on this device', Colors.red);
        return;
      }

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
      debugPrint('Error initializing web camera: $e');
      if (!mounted) return;
      _showTopBanner('Error initializing camera: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _requestPermissions() async {
    // Request camera, microphone, and location permissions on iOS
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();

    // DEBUG: log the raw permission results
    debugPrint('🛠️ Permission statuses: $statuses');

    // Treat "limited" as granted (iOS 13+ location limited state)
    final denied = statuses.entries
        .where((entry) =>
            !(entry.value.isGranted ||
              entry.value == PermissionStatus.limited))
        .map((entry) => entry.key)
        .toList();

    if (denied.isNotEmpty) {
      // If any truly denied, show a one-time dialog directing user to Settings
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Permissions Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please grant these permissions in Settings:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (var p in denied)
                Text('• ${_describeIosPermission(p)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    // All required permissions are granted (or limited) → proceed
    await _initializeCamera();
    await _getCurrentLocation();
    await _startP2PServices();
  }

  String _describeIosPermission(Permission p) {
    switch (p) {
      case Permission.camera:
        return 'Camera';
      case Permission.microphone:
        return 'Microphone';
      case Permission.location:
        return 'Location';
      default:
        return p.toString();
    }
  }

  Future<void> _startP2PServices() async {
    if (kIsWeb) return; // Skip P2P services on web
    
    try {
      // Initialize P2P services
      await Future.wait([
        _p2pService.startAdvertising(),
        _p2pService.startDiscovery(),
      ]);
    } catch (e) {
      debugPrint('Error starting P2P services: $e');
      if (!mounted) return;
      
      _showTopBanner('P2P service error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (kIsWeb) {
        // For web, check if geolocation is supported
        if (!await Geolocator.isLocationServiceEnabled()) {
          _showTopBanner('Please enable location services in your browser', Colors.orange);
          return;
        }

        // Request permission
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _showTopBanner('Please allow location access in your browser', Colors.red);
            return;
          }
        }

        // Get location with retries
        Position? position;
        int retryCount = 0;
        const maxRetries = 3;

        while (position == null && retryCount < maxRetries) {
          try {
            // For web, use lower accuracy to improve success rate
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 10),
            );
          } catch (e) {
            debugPrint('Attempt ${retryCount + 1} failed: $e');
            retryCount++;
            
            if (retryCount < maxRetries) {
              // Show feedback to user
              _showTopBanner(
                'Retrying location access... (${retryCount + 1}/$maxRetries)',
                Colors.orange
              );
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }

        if (position == null) {
          if (mounted) {
            _showTopBanner(
              'Could not get location. Emergency services may have limited accuracy.',
              Colors.orange
            );
            // Set a default position for web when location fails
            position = Position(
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
          }
        }

        if (mounted && position != null) {
          setState(() {
            _currentPosition = position;
          });
        }
        return;
      }

      // Mobile location handling continues as before
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
      if (!mounted) return;
      
      _showTopBanner('Error getting location: ${e.toString()}', Colors.orange);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Get cameras first to check if hardware is available
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        _showTopBanner('No cameras available on this device', Colors.red);
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
      _showTopBanner('Error initializing camera. Please check permissions and try again.', Colors.red);
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
      
      if (kIsWeb) {
        // For web, we need to get the data URL
        final bytes = await photo.readAsBytes();
        final base64 = base64Encode(bytes);
        final dataUrl = 'data:image/jpeg;base64,$base64';
        setState(() {
          _photoPath = dataUrl;
        });
      } else {
        setState(() {
          _photoPath = photo.path;
        });
      }
      
      _analyzeScene();
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      _showTopBanner('Error capturing photo: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      try {
        if (_isRecording) {
          // Stop recording
          js.context.callMethod('stopRecording');
          
          // Wait longer for audio processing
          await Future.delayed(const Duration(seconds: 1));
          
          // Get audio data from JavaScript
          final recorder = js.context['flutterWebRecorder'];
          final audioData = recorder['audioData'];
          final error = recorder['error'];
          
          if (error != null) {
            throw Exception(error.toString());
          }
          
          if (audioData == null) {
            throw Exception('No audio data received');
          }
          
          setState(() {
            _audioPath = audioData.toString();
            _isRecording = false;
          });
          
          // Wait a moment before analyzing to ensure audio is processed
          await Future.delayed(const Duration(milliseconds: 500));
          _analyzeScene();
        } else {
          // Start recording
          await js.context.callMethod('startRecording');
          setState(() {
            _isRecording = true;
          });
        }
      } catch (e) {
        debugPrint('Error with web audio recording: $e');
        setState(() {
          _isRecording = false;
        });
        _showTopBanner('Error with audio recording: ${e.toString()}', Colors.red);
      }
      return;
    }

    // Mobile recording logic
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _audioPath = path;
        _isRecording = false;
      });
      _analyzeScene();
    } else {
      try {
        final random = Random();
        final randomId = List.generate(10, (_) => random.nextInt(10)).join();
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: 'recording_$randomId.wav',
        );
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        debugPrint('Error starting recording: $e');
        _showTopBanner('Error starting recording: ${e.toString()}', Colors.red);
      }
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

      // Remove success message
      if (!mounted) return;
      // _showTopBanner('Scene analysis completed', Colors.green);
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
      _showTopBanner('Error analyzing scene: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _sendEmergencyData() async {
    if (_photoPath == null) {
      _showTopBanner('Please capture a photo first', Colors.red);
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
        analysis: _analysis,
      );

      if (!kIsWeb) {
        await emergencyData.save();
      }

      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
      });

      // Navigate to result screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyResultScreen(
            emergencyData: emergencyData,
            initialAnalysis: _analysis ?? {},
            openAIService: _openAIService,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error sending emergency data: $e');
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
      });

      _showTopBanner('Error sending emergency data: ${e.toString()}', Colors.red);
    }
  }

  @override
  void dispose() {
    _analysisSubscription?.cancel();
    _cameraController?.dispose();
    _audioRecorder.dispose();
    if (!kIsWeb) {
      _p2pService.stopAllEndpoints();
    }
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
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                          '${_currentPosition!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
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

  // Helper method to show messages at the top
  void _showTopBanner(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }
} 
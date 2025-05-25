import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/emergency_capture_screen.dart';
import 'screens/emergency_services_screen.dart';

void main() {
  runZonedGuarded(() async {
    // Ensure Flutter bindings are initialized before anything else
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('Warning: .env file not found. Using fallback configuration.');
      dotenv.env['OPENAI_API_KEY'] = '';
    }

    // For testing, start with a simple app first
    if (kIsWeb) {
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Loading ResQ...', 
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      ));

      // Short delay to ensure the test app renders
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Now run the real app
    runApp(const ResQApp());
  }, (error, stack) {
    // Catch all Flutter initialization errors
    debugPrint('🔥 Zone error: $error');
    debugPrint(stack.toString());
  });
}

class ResQApp extends StatelessWidget {
  const ResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          primary: Colors.red,
          secondary: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const EmergencyHomePage(),
    );
  }
}

class EmergencyHomePage extends StatelessWidget {
  const EmergencyHomePage({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    if (!kIsWeb) {
      // Mobile permissions
      debugPrint('Requesting camera...');
      final camera = await Permission.camera.request();
      debugPrint('Camera result: $camera');

      debugPrint('Requesting microphone...');
      final mic = await Permission.microphone.request();
      debugPrint('Microphone result: $mic');

      debugPrint('Requesting location...');
      final location = await Permission.locationWhenInUse.request();
      debugPrint('Location result: $location');
    }
    // Web permissions will be requested by the browser when needed
  }

  void _navigateToEmergencyCapture(BuildContext context) async {
    if (!kIsWeb) {
      await _requestPermissions(context);
      if (!context.mounted) return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyCaptureScreen(),
      ),
    );
  }

  void _navigateToEmergencyServices(BuildContext context) async {
    if (!kIsWeb) {
      await _requestPermissions(context);
      if (!context.mounted) return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyServicesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red, Colors.redAccent, Colors.deepOrange],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emergency,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ResQ',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Are you in danger?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: () => _navigateToEmergencyCapture(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'YES - Need Help Now',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => _navigateToEmergencyServices(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'I am Emergency Services',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'emergency_capture_screen.dart';
import 'emergency_services_screen.dart';

class EmergencyHomePage extends StatefulWidget {
  const EmergencyHomePage({super.key});

  @override
  State<EmergencyHomePage> createState() => _EmergencyHomePageState();
}

class _EmergencyHomePageState extends State<EmergencyHomePage> {
  @override
  void initState() {
    super.initState();
    // Request permissions as soon as screen loads
    Permission.camera.request();
    Permission.microphone.request();
    Permission.locationWhenInUse.request();
  }

  void _navigateToEmergencyCapture() {
    if (dotenv.env['OPENAI_API_KEY']?.isEmpty ?? true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Configuration Required'),
          content: const Text(
            'Please add your OpenAI API key to the .env file to enable AI analysis features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyCaptureScreen(),
      ),
    );
  }

  void _navigateToEmergencyServices() {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ResQ Link',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Are you in danger?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _navigateToEmergencyCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('YES - Need Help Now'),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _navigateToEmergencyServices,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                  ),
                ),
                child: const Text('I am Emergency Services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
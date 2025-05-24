import 'dart:io';
import 'package:flutter/material.dart';
import '../models/emergency_data.dart';

class EmergencyResultScreen extends StatelessWidget {
  final EmergencyData emergencyData;
  final Map<String, dynamic> analysis;

  const EmergencyResultScreen({
    super.key,
    required this.emergencyData,
    required this.analysis,
  });

  List<String> _getSafetyTips(String situation) {
    // Simplified safety tips based on the situation
    switch (situation.toLowerCase()) {
      case 'fire detected':
        return [
          'Stay low to avoid smoke inhalation',
          'Feel doors for heat before opening',
          'Use stairs, not elevators',
          'Call emergency services if safe to do so',
          'Meet at your designated meeting point',
        ];
      case 'structural damage':
        return [
          'Stay away from damaged areas',
          'Be aware of falling debris',
          'Listen for official instructions',
          'Avoid using elevators',
          'Help others if safe to do so',
        ];
      case 'flooding':
        return [
          'Move to higher ground',
          'Avoid walking through moving water',
          'Stay away from electrical equipment',
          'Be prepared to evacuate',
          'Listen to emergency broadcasts',
        ];
      case 'debris':
        return [
          'Stay away from unstable structures',
          'Watch for falling objects',
          'Use protective gear if available',
          'Follow evacuation orders',
          'Help others if safe to do so',
        ];
      default:
        return [
          'Stay calm and assess the situation',
          'Call emergency services if needed',
          'Follow official instructions',
          'Help others if safe to do so',
          'Stay informed through local news',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final situation = analysis['detectedSituation'] as String;
    final severity = analysis['severity'] as String;
    final safetyTips = _getSafetyTips(situation);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Analysis'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (emergencyData.photoPath != null)
              Image.file(
                File(emergencyData.photoPath!),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Situation Detected: $situation',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Severity Level: $severity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Latitude: ${emergencyData.latitude}\nLongitude: ${emergencyData.longitude}',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Safety Tips',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...safetyTips.map((tip) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text(tip)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  if (emergencyData.audioPath != null) ...[
                    Text(
                      'Audio Recording',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    // TODO: Add audio playback widget
                    const Text('Audio recording available'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Back to Camera'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyServicesScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Emergency Services View'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
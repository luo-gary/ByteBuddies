import 'package:flutter/material.dart';
import '../models/emergency_data.dart';

class EmergencyServicesScreen extends StatefulWidget {
  const EmergencyServicesScreen({super.key});

  @override
  State<EmergencyServicesScreen> createState() => _EmergencyServicesScreenState();
}

class _EmergencyServicesScreenState extends State<EmergencyServicesScreen> {
  List<EmergencyData> _emergencyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmergencyData();
  }

  Future<void> _loadEmergencyData() async {
    try {
      final data = await EmergencyData.loadEmergencyData();
      setState(() {
        _emergencyData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading emergency data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Services Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emergencyData.isEmpty
              ? const Center(
                  child: Text('No emergency reports found'),
                )
              : ListView.builder(
                  itemCount: _emergencyData.length,
                  itemBuilder: (context, index) {
                    final data = _emergencyData[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(
                          'Emergency Report ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time: ${data.timestamp.toString()}',
                            ),
                            Text(
                              'Location: ${data.latitude}, ${data.longitude}',
                            ),
                            if (data.photoPath != null)
                              const Text('Photo Available'),
                            if (data.audioPath != null)
                              const Text('Audio Recording Available'),
                          ],
                        ),
                        onTap: () {
                          // TODO: Show detailed view with photo and audio playback
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEmergencyData,
        backgroundColor: Colors.red,
        child: const Icon(Icons.refresh),
      ),
    );
  }
} 
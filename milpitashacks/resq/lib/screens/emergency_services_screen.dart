import 'package:flutter/material.dart';
import '../models/emergency_data.dart';
import 'package:intl/intl.dart';

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

  String _formatLocation(double lat, double long) {
    if (lat == 0 && long == 0) {
      return 'Location not available';
    }
    return '${lat.toStringAsFixed(4)}, ${long.toStringAsFixed(4)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y h:mm a').format(dateTime);
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
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Emergency Report ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Time: ${_formatDateTime(data.timestamp)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Location: ${_formatLocation(data.latitude, data.longitude)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (data.photoPath != null)
                                  Chip(
                                    label: const Text('Photo'),
                                    avatar: const Icon(Icons.camera_alt, size: 16),
                                    backgroundColor: Colors.blue.withOpacity(0.1),
                                  ),
                                const SizedBox(width: 8),
                                if (data.audioPath != null)
                                  Chip(
                                    label: const Text('Audio'),
                                    avatar: const Icon(Icons.mic, size: 16),
                                    backgroundColor: Colors.green.withOpacity(0.1),
                                  ),
                              ],
                            ),
                          ],
                        ),
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
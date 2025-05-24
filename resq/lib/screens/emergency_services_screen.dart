import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/emergency_data.dart';
import '../utils/permission_handler.dart';
import 'package:intl/intl.dart';

class EmergencyServicesScreen extends StatefulWidget {
  const EmergencyServicesScreen({super.key});

  @override
  State<EmergencyServicesScreen> createState() => _EmergencyServicesScreenState();
}

class _EmergencyServicesScreenState extends State<EmergencyServicesScreen> with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  List<EmergencyData> _emergencyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePermissionsThenLoad();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  Future<void> _checkPermissionsOnResume() async {
    if (!Platform.isIOS) return;
    
    final statuses = await Future.wait([
      Permission.camera.status,
      Permission.microphone.status,
      Permission.locationWhenInUse.status,
    ]);

    if (statuses.every((status) => status.isGranted || status == PermissionStatus.limited)) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      if (_emergencyData.isEmpty) {
        await _loadEmergencyData();
      }
    }
  }

  Future<void> _ensurePermissionsThenLoad() async {
    await PermissionUtil.requestIosPermissions(context);
    
    final statuses = await Future.wait([
      Permission.camera.status,
      Permission.microphone.status,
      Permission.locationWhenInUse.status,
    ]);

    if (statuses.every((status) => status.isGranted || status == PermissionStatus.limited)) {
      await _loadEmergencyData();
    }
  }

  Future<void> _loadEmergencyData() async {
    setState(() => _isLoading = true);
    try {
      final reports = await EmergencyData.getAllReports();
      setState(() {
        _emergencyData = reports;
      });
    } catch (e) {
      debugPrint('Error loading emergency data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAudioPlayback(String? audioPath, String emergencyId) async {
    if (audioPath == null) return;

    try {
      if (_currentlyPlayingId == emergencyId) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingId = null);
      } else {
        if (_currentlyPlayingId != null) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(DeviceFileSource(audioPath));
        setState(() => _currentlyPlayingId = emergencyId);
        
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() => _currentlyPlayingId = null);
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audio: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  void _showEmergencyDetails(EmergencyData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Emergency Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Time', _formatDateTime(data.timestamp)),
                _buildDetailRow('Location', _formatLocation(data.latitude, data.longitude)),
                if (data.photoPath != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Photo Evidence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(data.photoPath!),
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 50),
                              SizedBox(height: 8),
                              Text('Error loading image'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (data.audioPath != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Audio Recording',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => _toggleAudioPlayback(data.audioPath, data.id),
                        icon: Icon(
                          _currentlyPlayingId == data.id ? Icons.stop : Icons.play_arrow,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Reports'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emergencyData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.green[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No Active Emergencies',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The area is currently safe',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _emergencyData.length,
                  itemBuilder: (context, index) {
                    final data = _emergencyData[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () => _showEmergencyDetails(data),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Emergency Report',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(data.timestamp),
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
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
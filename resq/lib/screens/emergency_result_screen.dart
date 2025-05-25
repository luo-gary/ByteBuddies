import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_data.dart';
import '../services/openai_service.dart';

class EmergencyResultScreen extends StatefulWidget {
  final EmergencyData emergencyData;
  final Map<String, dynamic> initialAnalysis;
  final OpenAIService openAIService;

  const EmergencyResultScreen({
    super.key,
    required this.emergencyData,
    required this.initialAnalysis,
    required this.openAIService,
  });

  @override
  State<EmergencyResultScreen> createState() => _EmergencyResultScreenState();
}

class _EmergencyResultScreenState extends State<EmergencyResultScreen> {
  late Map<String, dynamic> _analysis;
  bool _isAnalyzing = true;
  StreamSubscription? _analysisSubscription;

  @override
  void initState() {
    super.initState();
    _analysis = widget.initialAnalysis;
    _listenToAnalysisUpdates();
  }

  void _listenToAnalysisUpdates() {
    _analysisSubscription = widget.openAIService.analysisStream.listen(
      (updatedAnalysis) {
        setState(() {
          _analysis = updatedAnalysis;
          _isAnalyzing = updatedAnalysis['isAnalyzing'] ?? false;
        });
      },
      onError: (error) {
        debugPrint('Error in analysis stream: $error');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _analysisSubscription?.cancel();
    super.dispose();
  }

  String _formatLocation(double lat, double long) {
    if (lat == 0 && long == 0) {
      return 'Location not available';
    }
    return '${lat.toStringAsFixed(6)}, ${long.toStringAsFixed(6)}';
  }

  final String emergencyNumber = "16507328894";

  Future<void> _callEmergencyServices() async {
    final Uri phoneUri = Uri.parse('tel:$emergencyNumber');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint('Could not launch phone call');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Emergency Analysis'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Status Card
            Card(
              elevation: 4,
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _analysis['detectedSituation'] ?? 'Emergency Reported',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_analysis['severity'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Severity: ${_analysis['severity']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Location: ${_formatLocation(widget.emergencyData.latitude, widget.emergencyData.longitude)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Safety Tips Section
            if (_analysis['safetyTips'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'IMMEDIATE ACTIONS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...(_analysis['safetyTips'] as List<dynamic>).map((tip) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Situation Details
            if (_analysis['description'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Situation Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _analysis['description'],
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Building Information
            if (_analysis['buildingInfo'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.business,
                          color: Colors.blue,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Building Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_analysis['address'] != null) ...[
                      Text(
                        _analysis['address'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _analysis['buildingInfo'],
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Emergency Guidance
            if (_analysis['emergencyGuidance'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Emergency Guidance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _analysis['emergencyGuidance'],
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Audio Analysis
            if (_analysis['transcription'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.mic,
                          color: Colors.blue,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Audio Analysis',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _analysis['transcription'],
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    if (_analysis['audioKeywords'] != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Key Points:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_analysis['audioKeywords'] as List<dynamic>).map((keyword) => Chip(
                          label: Text(keyword.toString()),
                          backgroundColor: Colors.blue.shade100,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            
            // Emergency Contact Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _callEmergencyServices(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.phone),
                label: const Text(
                  'Call Emergency Services',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
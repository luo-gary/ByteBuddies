import 'package:flutter/material.dart';
import '../services/safety_tips_service.dart';

class SafetyTipsScreen extends StatelessWidget {
  final String? detectedSituation;
  final SafetyTipsService _safetyTipsService = SafetyTipsService();

  SafetyTipsScreen({super.key, this.detectedSituation});

  @override
  Widget build(BuildContext context) {
    final tips = detectedSituation != null
        ? _safetyTipsService.getTipsForSituation(detectedSituation!)
        : _safetyTipsService.getAllTips();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detectedSituation != null
              ? 'Safety Tips: ${detectedSituation!}'
              : 'Emergency Safety Tips',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                tips[index],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'These tips are stored locally and available offline. '
            'Follow them carefully and wait for professional help when possible.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
} 
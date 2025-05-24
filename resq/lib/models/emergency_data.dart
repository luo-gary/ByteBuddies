import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class EmergencyData {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? photoPath;
  final String? audioPath;
  final Map<String, dynamic>? analysis;

  EmergencyData({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.photoPath,
    this.audioPath,
    this.analysis,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'photoPath': photoPath,
    'audioPath': audioPath,
    'analysis': analysis,
  };

  factory EmergencyData.fromJson(Map<String, dynamic> json) => EmergencyData(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    latitude: json['latitude'],
    longitude: json['longitude'],
    photoPath: json['photoPath'],
    audioPath: json['audioPath'],
    analysis: json['analysis'],
  );

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _storageFile async {
    final path = await _localPath;
    return File('$path/emergency_reports.json');
  }

  // Save a new emergency report
  Future<void> save() async {
    try {
      final file = await _storageFile;
      List<Map<String, dynamic>> reports = [];
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          reports = List<Map<String, dynamic>>.from(jsonDecode(contents));
        }
      }

      reports.add(toJson());
      await file.writeAsString(jsonEncode(reports));
    } catch (e) {
      debugPrint('Error saving emergency report: $e');
      rethrow;
    }
  }

  // Get all emergency reports
  static Future<List<EmergencyData>> getAllReports() async {
    try {
      final file = await _storageFile;
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => EmergencyData.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading emergency reports: $e');
      return [];
    }
  }

  // Delete media files when report is no longer needed
  Future<void> deleteMediaFiles() async {
    try {
      if (photoPath != null) {
        final photoFile = File(photoPath!);
        if (await photoFile.exists()) {
          await photoFile.delete();
        }
      }
      if (audioPath != null) {
        final audioFile = File(audioPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting media files: $e');
    }
  }
} 
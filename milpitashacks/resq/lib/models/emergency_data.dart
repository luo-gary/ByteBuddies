import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class EmergencyData {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? photoPath;
  final String? audioPath;
  bool isSent;

  EmergencyData({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.photoPath,
    this.audioPath,
    this.isSent = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'photoPath': photoPath,
      'audioPath': audioPath,
      'isSent': isSent,
    };
  }

  factory EmergencyData.fromJson(Map<String, dynamic> json) {
    return EmergencyData(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      latitude: json['latitude'],
      longitude: json['longitude'],
      photoPath: json['photoPath'],
      audioPath: json['audioPath'],
      isSent: json['isSent'],
    );
  }

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/emergency_data.json');
  }

  static Future<void> saveEmergencyData(EmergencyData data) async {
    try {
      final file = await _localFile;
      List<EmergencyData> existingData = await loadEmergencyData();
      existingData.add(data);
      
      final jsonList = existingData.map((data) => data.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving emergency data: $e');
    }
  }

  static Future<List<EmergencyData>> loadEmergencyData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList
          .map((json) => EmergencyData.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading emergency data: $e');
      return [];
    }
  }

  static Future<List<EmergencyData>> getUnsentEmergencyData() async {
    final allData = await loadEmergencyData();
    return allData.where((data) => !data.isSent).toList();
  }

  Future<void> markAsSent() async {
    isSent = true;
    List<EmergencyData> allData = await loadEmergencyData();
    int index = allData.indexWhere((data) => data.id == id);
    if (index != -1) {
      allData[index] = this;
      final file = await _localFile;
      final jsonList = allData.map((data) => data.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    }
  }
} 
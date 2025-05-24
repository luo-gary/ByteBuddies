import '../services/database_service.dart';

class EmergencyData {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? photoPath;
  final String? audioPath;

  EmergencyData({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.photoPath,
    this.audioPath,
  });

  static Future<void> saveEmergencyData(
    EmergencyData data, {
    Map<String, dynamic>? analysis,
  }) async {
    final db = DatabaseService();
    await db.saveEmergencyReport(
      data: data,
      analysis: analysis,
    );
  }

  static Future<void> updateAnalysis(
    String id,
    Map<String, dynamic> analysis,
  ) async {
    final db = DatabaseService();
    await db.updateAnalysis(id, analysis);
  }

  static Future<void> markAsSentToServices(String id) async {
    final db = DatabaseService();
    await db.markAsSentToServices(id);
  }

  static Future<List<Map<String, dynamic>>> getAllReports() async {
    final db = DatabaseService();
    return await db.getEmergencyReports();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'photoPath': photoPath,
      'audioPath': audioPath,
    };
  }

  factory EmergencyData.fromJson(Map<String, dynamic> json) {
    return EmergencyData(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      photoPath: json['photo_path'] as String?,
      audioPath: json['audio_path'] as String?,
    );
  }
} 
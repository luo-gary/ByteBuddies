import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/emergency_data.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'emergency_reports.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE emergency_reports (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            photo_path TEXT,
            audio_path TEXT,
            analysis TEXT,
            sent_to_services INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> saveEmergencyReport({
    required EmergencyData data,
    Map<String, dynamic>? analysis,
  }) async {
    final db = await database;
    await db.insert(
      'emergency_reports',
      {
        'id': data.id,
        'timestamp': data.timestamp.toIso8601String(),
        'latitude': data.latitude,
        'longitude': data.longitude,
        'photo_path': data.photoPath,
        'audio_path': data.audioPath,
        'analysis': analysis != null ? jsonEncode(analysis) : null,
        'sent_to_services': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getEmergencyReports() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('emergency_reports');
    return maps.map((map) {
      if (map['analysis'] != null) {
        map['analysis'] = jsonDecode(map['analysis'] as String);
      }
      return map;
    }).toList();
  }

  Future<void> markAsSentToServices(String id) async {
    final db = await database;
    await db.update(
      'emergency_reports',
      {'sent_to_services': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAnalysis(String id, Map<String, dynamic> analysis) async {
    final db = await database;
    await db.update(
      'emergency_reports',
      {'analysis': jsonEncode(analysis)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 
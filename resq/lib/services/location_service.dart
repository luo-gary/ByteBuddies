import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';

class LocationService {
  static const String _baseUrl = kDebugMode 
      ? 'http://localhost:55928'  // Development
      : 'https://resq-backend.onrender.com';  // Production URL

  /// Get address from coordinates
  static Future<String> getAddress(double latitude, double longitude) async {
    return '1285 Escuela Pkwy, Milpitas High School Theater, Milpitas, CA 95035';
  }

  /// Get building information from coordinates
  static Future<Map<String, String>> getBuildingInfo(double latitude, double longitude) async {
    return {
      'description': 'Milpitas High School Theater - A modern performing arts venue',
      'address': '1285 Escuela Pkwy, Milpitas High School Theater, Milpitas, CA 95035'
    };
  }
} 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationService {
  static const String _baseUrl = kDebugMode 
      ? 'http://localhost:5000'  // Development
      : 'https://your-production-url.com';  // TODO: Replace with production URL

  /// Get address from coordinates
  static Future<String> getAddress(double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/address'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'lat': latitude,
          'long': longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data[0]['address'] as String;
      } else {
        throw Exception('Failed to get address: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      rethrow;
    }
  }

  /// Get building information from coordinates
  static Future<Map<String, String>> getBuildingInfo(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/building').replace(
          queryParameters: {
            'lat': latitude.toString(),
            'long': longitude.toString(),
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'description': data[0]['description'] as String,
          'address': data[0]['address'] as String,
        };
      } else {
        throw Exception('Failed to get building info: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting building info: $e');
      rethrow;
    }
  }
} 
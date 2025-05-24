import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com';
  late final String _apiKey;
  
  OpenAIService() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please add it to your .env file.');
    }
  }

  Future<Map<String, dynamic>> analyzeEmergencyScene({
    required String imagePath,
    String? audioPath,
  }) async {
    try {
      // Image analysis
      final imageAnalysis = await _analyzeImage(imagePath);
      
      // Audio analysis if available
      final audioAnalysis = audioPath != null 
        ? await _analyzeAudio(audioPath)
        : null;

      // Combine analyses
      return {
        'detectedSituation': imageAnalysis['situation'],
        'severity': imageAnalysis['severity'],
        'description': imageAnalysis['description'],
        if (audioAnalysis != null) 'audioKeywords': audioAnalysis['keywords'],
      };
    } catch (e) {
      debugPrint('Error analyzing emergency scene: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _analyzeImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found at path: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      debugPrint('Sending image analysis request...');
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this emergency situation image and provide:\n1. Type of emergency situation\n2. Severity level (High/Medium/Low)\n3. A detailed description of what you see',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                    'detail': 'high',
                  },
                },
              ],
            },
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      debugPrint('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        debugPrint('Analysis response: $content');
        
        // Parse the response
        final lines = content.split('\n');
        String situation = 'Emergency Situation';
        String severity = 'Medium';
        String description = content;

        for (final line in lines) {
          if (line.toLowerCase().contains('type:') || line.toLowerCase().contains('situation:')) {
            situation = line.split(':')[1].trim();
          } else if (line.toLowerCase().contains('severity:')) {
            severity = line.split(':')[1].trim();
          }
        }

        return {
          'situation': situation,
          'severity': severity,
          'description': description,
        };
      } else {
        final errorBody = response.body;
        debugPrint('OpenAI API Error Response: $errorBody');
        throw Exception('Failed to analyze image: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('Error in image analysis: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _analyzeAudio(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found at path: $audioPath');
      }
      
      // Create multipart request for audio transcription
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/v1/audio/transcriptions'))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['response_format'] = 'json'
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final transcription = jsonDecode(response.body)['text'];
        
        // Analyze transcription for keywords
        final keywordResponse = await http.post(
          Uri.parse('$_baseUrl/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-4',
            'messages': [
              {
                'role': 'system',
                'content': 'Extract important keywords related to emergency situations from the following audio transcription.',
              },
              {
                'role': 'user',
                'content': transcription,
              },
            ],
            'max_tokens': 100,
          }),
        );

        if (keywordResponse.statusCode == 200) {
          final keywords = jsonDecode(keywordResponse.body)['choices'][0]['message']['content']
            .split(',')
            .map((k) => k.trim())
            .toList();

          return {
            'transcription': transcription,
            'keywords': keywords,
          };
        } else {
          debugPrint('OpenAI API Error (Keywords): ${keywordResponse.statusCode} - ${keywordResponse.body}');
          throw Exception('Failed to analyze audio keywords');
        }
      } else {
        debugPrint('OpenAI API Error (Transcription): ${response.statusCode} - ${response.body}');
        throw Exception('Failed to transcribe audio');
      }
    } catch (e) {
      debugPrint('Error in audio analysis: $e');
      rethrow;
    }
  }
} 
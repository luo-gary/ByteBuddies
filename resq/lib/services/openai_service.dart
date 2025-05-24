import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  final String _baseUrl = 'https://api.openai.com/v1';
  late final String _apiKey;
  final _analysisController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get analysisStream => _analysisController.stream;
  
  OpenAIService() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not found in .env file');
    }
  }

  Future<Map<String, dynamic>> analyzeEmergencyScene({
    required String imagePath,
    String? audioPath,
  }) async {
    // Return immediate default response
    final defaultResponse = {
      'detectedSituation': 'Emergency Situation',
      'severity': 'Medium',
      'description': 'Analysis in progress...',
      'isAnalyzing': true,
    };

    // Start background analysis
    _startBackgroundAnalysis(imagePath, audioPath);

    return defaultResponse;
  }

  Future<void> _startBackgroundAnalysis(String imagePath, String? audioPath) async {
    try {
      // Start both analyses concurrently
      final imageAnalysisFuture = _analyzeImage(imagePath);
      final audioAnalysisFuture = audioPath != null ? _analyzeAudio(audioPath) : null;

      // Wait for image analysis
      final imageAnalysis = await imageAnalysisFuture;
      _analysisController.add({
        ...imageAnalysis,
        'isAnalyzing': audioPath != null,
      });

      // If there's audio, wait for its analysis
      if (audioAnalysisFuture != null) {
        final audioAnalysis = await audioAnalysisFuture;
        _analysisController.add({
          ...imageAnalysis,
          'audioKeywords': audioAnalysis['keywords'],
          'transcription': audioAnalysis['transcription'],
          'isAnalyzing': false,
        });
      }
    } catch (e) {
      debugPrint('Error in background analysis: $e');
      _analysisController.add({
        'detectedSituation': 'Emergency Situation',
        'severity': 'Unknown',
        'description': 'Analysis failed. Please proceed with caution.',
        'isAnalyzing': false,
        'error': e.toString(),
      });
    }
  }

  Future<Map<String, dynamic>> _analyzeImage(String imagePath) async {
    try {
      late final String base64Image;
      
      if (kIsWeb) {
        // For web, imagePath will be a data URL
        if (imagePath.startsWith('data:image')) {
          base64Image = imagePath.split(',')[1];
        } else {
          throw Exception('Invalid image format for web');
        }
      } else {
        // For mobile, read the file
        final imageBytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an emergency situation analyzer. Analyze the image and provide two responses: 1) A detailed analysis for emergency services, and 2) 3-4 critical, very brief safety tips for the person in danger.',
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this emergency scene. Provide: 1) A detailed situation report for emergency services, and 2) 3-4 immediate, critical safety tips for the person (each tip should be under 8 words).',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseAnalysisResponse(content);
      } else {
        debugPrint('OpenAI API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to analyze emergency scene: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      return {
        'detectedSituation': 'Emergency Situation',
        'severity': 'Unknown',
        'description': 'Unable to analyze the image. Please proceed with caution.',
        'safetyTips': [
          'Stay away from immediate danger',
          'Call emergency services',
          'Follow official instructions',
        ],
      };
    }
  }

  Map<String, dynamic> _parseAnalysisResponse(String content) {
    try {
      final lines = content.split('\n');
      String situation = 'Emergency Situation';
      String severity = 'Medium';
      String description = '';
      List<String> safetyTips = [];
      bool parsingTips = false;

      for (final line in lines) {
        if (line.toLowerCase().contains('situation:')) {
          situation = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('severity:')) {
          severity = line.split(':')[1].trim();
        } else if (line.toLowerCase().contains('safety tips:') || line.toLowerCase().contains('immediate actions:')) {
          parsingTips = true;
          continue;
        } else if (parsingTips && line.trim().startsWith('-')) {
          safetyTips.add(line.replaceFirst('-', '').trim());
        } else if (!parsingTips) {
          description += line + '\n';
        }
      }

      if (safetyTips.isEmpty) {
        safetyTips = [
          'Stay away from immediate danger',
          'Call emergency services',
          'Follow official instructions',
        ];
      }

      return {
        'detectedSituation': situation,
        'severity': severity,
        'description': description.trim(),
        'safetyTips': safetyTips,
      };
    } catch (e) {
      debugPrint('Error parsing analysis response: $e');
      return {
        'detectedSituation': 'Emergency Situation',
        'severity': 'Unknown',
        'description': content,
        'safetyTips': [
          'Stay away from immediate danger',
          'Call emergency services',
          'Follow official instructions',
        ],
      };
    }
  }

  Future<Map<String, dynamic>> _analyzeAudio(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found at path: $audioPath');
      }
      
      // Create multipart request for audio transcription
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/audio/transcriptions'))
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
          Uri.parse('$_baseUrl/chat/completions'),
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
      return {
        'transcription': 'Audio analysis failed',
        'keywords': ['error'],
      };
    }
  }

  void dispose() {
    _analysisController.close();
  }
} 
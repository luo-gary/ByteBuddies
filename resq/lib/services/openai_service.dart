import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resq/services/emergency_prompt_service.dart';
import 'package:resq/services/location_service.dart';

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
    Position? position,
  }) async {
    // Return immediate default response
    final defaultResponse = {
      'detectedSituation': 'Emergency Situation',
      'severity': 'Medium',
      'description': 'Analysis in progress...',
      'isAnalyzing': true,
    };

    // Start background analysis
    _startBackgroundAnalysis(imagePath, audioPath, position);

    return defaultResponse;
  }

  Future<void> _startBackgroundAnalysis(String imagePath, String? audioPath, Position? position) async {
    try {
      // Start all analyses concurrently
      final imageAnalysisFuture = _analyzeImage(imagePath);
      final audioAnalysisFuture = audioPath != null ? _analyzeAudio(audioPath) : null;
      final locationInfoFuture = position != null ? 
          LocationService.getBuildingInfo(position.latitude, position.longitude) : null;

      // Wait for image analysis
      final imageAnalysis = await imageAnalysisFuture;
      
      // Add location info if available
      Map<String, dynamic> combinedAnalysis = {...imageAnalysis};
      if (locationInfoFuture != null) {
        try {
          final locationInfo = await locationInfoFuture;
          combinedAnalysis['buildingInfo'] = locationInfo['description'];
          combinedAnalysis['address'] = locationInfo['address'];
        } catch (e) {
          debugPrint('Error getting location info: $e');
        }
      }

      // Generate emergency prompt based on situation
      final situation = EmergencyPromptService.parseSituation(combinedAnalysis['description']);
      final emergencyType = _determineEmergencyType(situation);
      if (emergencyType != null) {
        final prompt = EmergencyPromptService.generatePrompt(emergencyType, situation);
        try {
          final response = await _getEmergencyGuidance(prompt);
          combinedAnalysis['emergencyGuidance'] = response;
        } catch (e) {
          debugPrint('Error getting emergency guidance: $e');
        }
      }

      _analysisController.add({
        ...combinedAnalysis,
        'isAnalyzing': audioPath != null,
      });

      // If there's audio, wait for its analysis
      if (audioAnalysisFuture != null) {
        final audioAnalysis = await audioAnalysisFuture;
        _analysisController.add({
          ...combinedAnalysis,
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

  EmergencyType? _determineEmergencyType(Map<String, dynamic> situation) {
    final description = situation['description']?.toLowerCase() ?? '';
    if (description.contains('earthquake') || description.contains('shaking')) {
      return EmergencyType.earthquake;
    } else if (description.contains('fire') || description.contains('smoke')) {
      return EmergencyType.fire;
    } else if (description.contains('storm') || description.contains('hurricane') || 
               description.contains('tornado')) {
      return EmergencyType.storm;
    }
    return null;
  }

  Future<String> _getEmergencyGuidance(String prompt) async {
    try {
      final response = await http.post(
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
              'content': 'You are an emergency response expert providing critical safety guidance.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to get emergency guidance: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting emergency guidance: $e');
      rethrow;
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

      // Add retry logic for API calls
      int maxRetries = 3;
      int currentTry = 0;
      late http.Response response;

      while (currentTry < maxRetries) {
        try {
          response = await http.post(
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
          }

          // If we get here, it means we got a non-200 response
          debugPrint('OpenAI API Error: ${response.statusCode} - ${response.body}');
          
          // If we get a 429 (rate limit) or 5xx (server error), retry
          if ((response.statusCode == 429 || response.statusCode >= 500) && 
              currentTry < maxRetries - 1) {
            currentTry++;
            await Future.delayed(Duration(seconds: currentTry * 2)); // Exponential backoff
            continue;
          }
          
          throw Exception('Failed to analyze emergency scene: ${response.statusCode}');
        } catch (e) {
          if (e is http.ClientException && currentTry < maxRetries - 1) {
            currentTry++;
            debugPrint('Retrying API call after error: $e');
            await Future.delayed(Duration(seconds: currentTry * 2));
            continue;
          }
          rethrow;
        }
      }
      
      throw Exception('Failed to analyze emergency scene after $maxRetries attempts');
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
      late final http.MultipartFile audioFile;
      
      if (kIsWeb) {
        // For web, audioPath will be a blob URL
        if (audioPath.startsWith('blob:')) {
          // Fetch the blob data
          final response = await http.get(Uri.parse(audioPath));
          if (response.statusCode != 200) {
            throw Exception('Failed to fetch audio blob: ${response.statusCode}');
          }
          
          // Create a MultipartFile from the blob data with correct extension based on content type
          final contentType = response.headers['content-type'] ?? 'audio/webm';
          final extension = contentType.contains('webm') ? 'webm' : 
                          contentType.contains('mp4') ? 'm4a' :
                          contentType.contains('mpeg') ? 'mp3' : 'webm';
          
          audioFile = http.MultipartFile.fromBytes(
            'file',
            response.bodyBytes,
            filename: 'audio.$extension',
            contentType: MediaType.parse(contentType),
          );
        } else if (audioPath.startsWith('data:')) {
          // Handle data URL
          final contentType = audioPath.split(';')[0].split(':')[1];
          final data = audioPath.split(',')[1];
          final bytes = base64Decode(data);
          
          final extension = contentType.contains('webm') ? 'webm' : 
                          contentType.contains('mp4') ? 'm4a' :
                          contentType.contains('mpeg') ? 'mp3' : 'webm';
          
          audioFile = http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'audio.$extension',
            contentType: MediaType.parse(contentType),
          );
        } else {
          throw Exception('Invalid audio format for web');
        }
      } else {
        // For mobile, use the file path
        final file = File(audioPath);
        if (!await file.exists()) {
          throw Exception('Audio file not found at path: $audioPath');
        }
        audioFile = await http.MultipartFile.fromPath('file', file.path);
      }
      
      // Create multipart request for audio transcription
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/audio/transcriptions'))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['response_format'] = 'json'
        ..files.add(audioFile);

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
            .toList()
            .cast<String>();

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
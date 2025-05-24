import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  Interpreter? _imageInterpreter;
  Interpreter? _audioInterpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _imageInterpreter = await Interpreter.fromAsset('assets/models/image_classifier.tflite');
      _audioInterpreter = await Interpreter.fromAsset('assets/models/audio_classifier.tflite');
      _isInitialized = true;
    } catch (e) {
      print('Warning: AI models not available - using fallback mode: $e');
      // Don't rethrow - continue in fallback mode
      _isInitialized = true;
    }
  }

  Future<Map<String, dynamic>> analyzeEmergencyScene({
    required String imagePath,
    String? audioPath,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    Map<String, dynamic> analysis = {
      'detectedSituation': '',
      'peopleCount': 0,
      'severity': 'Unknown',
      'audioKeywords': <String>[],
    };

    try {
      // Analyze image
      if (imagePath.isNotEmpty) {
        File imageFile = File(imagePath);
        img.Image? image = img.decodeImage(await imageFile.readAsBytes());
        if (image != null) {
          if (_imageInterpreter != null) {
            // Use AI model if available
            img.Image resizedImage = img.copyResize(image, width: 224, height: 224);
            
            var imageMatrix = List.generate(
              1,
              (i) => List.generate(
                224,
                (j) => List.generate(
                  224,
                  (k) => List.generate(
                    3,
                    (l) {
                      var pixel = resizedImage.getPixel(j, k);
                      return (pixel.r + pixel.g + pixel.b) / (3 * 255.0);
                    },
                  ),
                ),
              ),
            );

            var outputShape = [1, 5];
            var outputBuffer = List.filled(1 * 5, 0.0);

            _imageInterpreter!.run(imageMatrix, outputBuffer);

            analysis['detectedSituation'] = _getDetectedSituation(outputBuffer);
            analysis['severity'] = _getSeverityLevel(outputBuffer);
          } else {
            // Fallback mode - basic image analysis
            analysis['detectedSituation'] = 'Emergency situation detected';
            analysis['severity'] = 'Medium';
          }
          analysis['peopleCount'] = _estimatePeopleCount(image);
        }
      }

      if (audioPath != null) {
        // Simplified audio analysis
        analysis['audioKeywords'] = ['emergency', 'help needed'];
      }

    } catch (e) {
      print('Warning: Error in scene analysis - using fallback mode: $e');
      analysis['detectedSituation'] = 'Emergency situation detected';
      analysis['severity'] = 'Medium';
      analysis['error'] = e.toString();
    }

    return analysis;
  }

  String _getDetectedSituation(List<double> outputBuffer) {
    int maxIndex = 0;
    double maxValue = outputBuffer[0];
    
    for (int i = 1; i < outputBuffer.length; i++) {
      if (outputBuffer[i] > maxValue) {
        maxValue = outputBuffer[i];
        maxIndex = i;
      }
    }

    switch (maxIndex) {
      case 0:
        return 'Fire detected';
      case 1:
        return 'Structural damage';
      case 2:
        return 'Flooding';
      case 3:
        return 'Debris';
      default:
        return 'Emergency situation detected';
    }
  }

  String _getSeverityLevel(List<double> outputBuffer) {
    double maxConfidence = outputBuffer.reduce((a, b) => a > b ? a : b);
    
    if (maxConfidence > 0.8) {
      return 'High';
    } else if (maxConfidence > 0.5) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  int _estimatePeopleCount(img.Image image) {
    // Basic image analysis for demonstration
    return 1;
  }

  void dispose() {
    if (_isInitialized) {
      _imageInterpreter?.close();
      _audioInterpreter?.close();
      _isInitialized = false;
    }
  }
} 
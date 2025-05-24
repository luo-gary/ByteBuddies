import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  late Interpreter _imageInterpreter;
  late Interpreter _audioInterpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _imageInterpreter = await Interpreter.fromAsset('assets/models/image_classifier.tflite');
      _audioInterpreter = await Interpreter.fromAsset('assets/models/audio_classifier.tflite');
      _isInitialized = true;
    } catch (e) {
      print('Error initializing AI models: $e');
      rethrow;
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
          // Resize image to match model input size (assuming 224x224)
          img.Image resizedImage = img.copyResize(image, width: 224, height: 224);
          
          // Convert image to float32 array and normalize
          var imageMatrix = List.generate(
            1,
            (i) => List.generate(
              224,
              (j) => List.generate(
                224,
                (k) => List.generate(
                  3,
                  (l) => resizedImage.getPixel(j, k).toDouble() / 255.0,
                ),
              ),
            ),
          );

          var outputShape = [1, 5]; // Assuming 5 classes
          var outputBuffer = List.filled(1 * 5, 0.0);

          _imageInterpreter.run(imageMatrix, outputBuffer);

          // Process image analysis results
          analysis['detectedSituation'] = _getDetectedSituation(outputBuffer);
          analysis['severity'] = _getSeverityLevel(outputBuffer);
          analysis['peopleCount'] = _estimatePeopleCount(image);
        }
      }

      // TODO: Implement audio analysis when audio model is ready
      if (audioPath != null) {
        analysis['audioKeywords'] = ['trapped', 'help', 'emergency'];
      }

    } catch (e) {
      print('Error analyzing emergency scene: $e');
      analysis['error'] = e.toString();
    }

    return analysis;
  }

  String _getDetectedSituation(List<double> outputBuffer) {
    // Simplified classification - in real app, would map to actual model outputs
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
        return 'Unknown situation';
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
    // Simplified person detection - in real app, would use proper object detection
    // This is just a placeholder implementation
    return 1;
  }

  void dispose() {
    if (_isInitialized) {
      _imageInterpreter.close();
      _audioInterpreter.close();
      _isInitialized = false;
    }
  }
} 
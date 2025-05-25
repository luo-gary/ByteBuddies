import 'package:flutter/foundation.dart';

enum EmergencyType {
  earthquake,
  fire,
  storm
}

class EmergencyPromptService {
  static String generatePrompt(EmergencyType type, Map<String, dynamic> situation) {
    final situationStr = situation.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');

    switch (type) {
      case EmergencyType.earthquake:
        return '''Tell me, using your knowledge about previous
    earthquakes and data from them, such as causes of death,
    and so on, how to best survive an earthquake with the particular important
    details that will be provided. Which places should 
     I avoid? Should I try to escape in a car? The situation is as follows: $situationStr.
    Be as brief as possible because in our use case, you will be telling
     someone who is in danger and possibly panicking. Be authoritative, 
     calm, and gentle. Seriously, be as brief as possible. Highly important:
      keep responses under 50 words.''';

      case EmergencyType.fire:
        return '''Tell me, using your knowledge about previous
    fires and data from them, such as causes of death,
    and so on, how to best survive an fires with the particular important
    details that will be provided. Which places should 
     I avoid? Should I try to escape in a car? The situation is as follows: $situationStr.
    Be as brief as possible because in our use case, you will be telling
     someone who is in danger and possibly panicking. Be authoritative, 
     calm, and gentle. Seriously, be as brief as possible. Highly important:
      keep responses under 50 words.''';

      case EmergencyType.storm:
        return '''Tell me, using your knowledge about previous
    storms, such as hurricanes and tornadoes, and data from them, such as causes of death,
    and so on, how to best survive an storm with the particular important
    details that will be provided. Which places should 
     I avoid? Should I try to escape in a car? The situation is as follows: $situationStr.
    Be as brief as possible because in our use case, you will be telling
     someone who is in danger and possibly panicking. Be authoritative, 
     calm, and gentle. Seriously, be as brief as possible. Highly important:
      keep responses under 50 words.''';
    }
  }

  static Map<String, dynamic> parseSituation(String description) {
    try {
      final parts = description.split(',').map((part) => part.trim());
      final situation = <String, dynamic>{};

      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          situation[keyValue[0].trim()] = keyValue[1].trim();
        }
      }

      return situation;
    } catch (e) {
      debugPrint('Error parsing situation: $e');
      return {
        'description': description,
        'severity': 'unknown'
      };
    }
  }
} 
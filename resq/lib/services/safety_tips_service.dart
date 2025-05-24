
class SafetyTipsService {
  static final SafetyTipsService _instance = SafetyTipsService._internal();
  factory SafetyTipsService() => _instance;
  SafetyTipsService._internal();

  static const Map<String, List<String>> _emergencyTips = {
    'Fire': [
      'Stay low to avoid smoke inhalation',
      'Feel doors for heat before opening',
      'Use stairs, not elevators',
      'Cover mouth with wet cloth if possible',
      'Follow exit signs and evacuation routes',
      'Once out, stay out',
      'Call emergency services if possible',
    ],
    'Structural damage': [
      'Drop, Cover, and Hold On',
      'Stay away from windows and exterior walls',
      'If trapped, tap on pipes or walls',
      'Whistle or shout for help to conserve energy',
      'Cover mouth with clothing for dust',
      'Avoid using elevators',
      'Watch for falling debris',
    ],
    'Flooding': [
      'Move to higher ground immediately',
      'Avoid walking through moving water',
      'Stay away from power lines and electrical wires',
      'Turn off utilities if safe to do so',
      'Avoid driving through flooded areas',
      'Listen for updates if possible',
      'Prepare for evacuation',
    ],
    'Unknown': [
      'Stay calm and assess the situation',
      'Check for injuries',
      'Look for safe exits',
      'Help others if safe to do so',
      'Avoid unnecessary movement if unsure',
      'Wait for professional help if possible',
      'Conserve phone battery',
    ],
  };

  List<String> getTipsForSituation(String situation) {
    // Normalize the situation string and find the best match
    final normalizedSituation = situation.toLowerCase();
    String bestMatch = 'Unknown';

    for (final type in _emergencyTips.keys) {
      if (normalizedSituation.contains(type.toLowerCase())) {
        bestMatch = type;
        break;
      }
    }

    return _emergencyTips[bestMatch] ?? _emergencyTips['Unknown']!;
  }

  String getPrioritizedTip(String situation) {
    final tips = getTipsForSituation(situation);
    return tips.first; // Return the most important tip first
  }

  List<String> getAllTips() {
    final allTips = <String>[];
    for (final tips in _emergencyTips.values) {
      allTips.addAll(tips);
    }
    return allTips..shuffle(); // Return shuffled list of all tips
  }
} 
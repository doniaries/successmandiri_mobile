import 'package:shared_preferences/shared_preferences.dart';

class SeenStateService {
  static const String _prefix = 'seen_state_';

  static Future<bool> isSeen(String resourceType, String latestId) async {
    if (latestId.isEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    final lastSeenId = prefs.getString(_prefix + resourceType);
    return lastSeenId == latestId;
  }

  static Future<void> markAsSeen(String resourceType, String latestId) async {
    if (latestId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + resourceType, latestId);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}


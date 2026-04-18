import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EventDraftStore {
  static const String draftKey = 'event_draft';

  static Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);
  }
}

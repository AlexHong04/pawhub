import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../module/auth/model/auth_model.dart';

class CurrentUserStore {
  static const String currentUserKey = 'current_user_data';
  static AuthModel? _memoryUser;

  static Future<void> save(AuthModel user) async {
    _memoryUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currentUserKey, jsonEncode(user.toJson()));
  }

  static Future<AuthModel?> read() async {
    if (_memoryUser != null) return _memoryUser;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(currentUserKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _memoryUser = AuthModel.fromJson(data);
      return _memoryUser;
    } catch (_) {
      await prefs.remove(currentUserKey);
      return null;
    }
  }

  static Future<void> clear() async {
    _memoryUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(currentUserKey);
  }
}


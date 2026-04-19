import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BiometricSessionService {
  static const String _biometricEnabledKey = 'biometric_login_enabled';
  static const String _refreshTokenKey = 'biometric_refresh_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> isSupported() async {
    try {
      return await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Biometric support check failed: $e');
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  static Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  static Future<bool> hasStoredSession() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  static Future<void> saveCurrentSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    final refreshToken = session?.refreshToken;

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return;
    }

    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<bool> restoreSessionFromSecureStorage() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) {
      return true;
    }

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.trim().isEmpty) return false;

    try {
      final dynamic auth = client.auth;

      // Supabase versions differ with some use setSession(refreshToken),
      // others recoverSession(serializedSession). Try both safely.
      try {
        await auth.setSession(refreshToken);
      } catch (_) {
        await auth.recoverSession(refreshToken);
      }

      return client.auth.currentSession != null;
    } catch (e) {
      debugPrint('Biometric session restore failed: $e');
      return false;
    }
  }

  static Future<bool> authenticate({
    String localizedReason = 'Please authenticate to unlock your session',
  }) async {
    try {
      if (!await isSupported()) return false;

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _biometricEnabledKey);
  }
}


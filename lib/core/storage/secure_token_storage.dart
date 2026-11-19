import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sanctum token storage backed by the platform secure store
/// (Android Keystore / iOS Keychain). Never falls back to plain storage.
class SecureTokenStorage {
  static const String _tokenKey = 'leadx_sanctum_token';
  static const String _loggedInKey = 'leadx_session_active';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<bool> get sessionActive async {
    final v = await _storage.read(key: _loggedInKey);
    return v == '1';
  }

  static Future<void> setSessionActive(bool active) =>
      _storage.write(key: _loggedInKey, value: active ? '1' : '0');

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _loggedInKey);
  }
}

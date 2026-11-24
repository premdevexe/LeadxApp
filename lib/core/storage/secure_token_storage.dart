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

  /// In-process mirrors of the two platform-store values. Every mutation in
  /// the app goes through this class, and the store is never written by
  /// another process, so after the first (cold-start) read both values
  /// resolve in memory — no platform-channel round-trip on every API
  /// request, which is how often [readToken] is actually called.
  static String? _tokenCache;
  static bool? _sessionCache;

  static Future<String?> readToken() async {
    if (_tokenCache != null) return _tokenCache;
    _tokenCache = await _storage.read(key: _tokenKey);
    return _tokenCache;
  }

  static Future<void> writeToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _tokenCache = token;
  }

  static Future<bool> get sessionActive async {
    if (_sessionCache != null) return _sessionCache!;
    final v = await _storage.read(key: _loggedInKey);
    _sessionCache = v == '1';
    return _sessionCache!;
  }

  static Future<void> setSessionActive(bool active) async {
    await _storage.write(key: _loggedInKey, value: active ? '1' : '0');
    _sessionCache = active;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _loggedInKey);
    _tokenCache = null;
    _sessionCache = null;
  }
}

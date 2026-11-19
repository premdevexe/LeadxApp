import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detailed result of a biometric authentication attempt.
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
  });
}

/// Native biometric authentication and app-lock protection for LeadX.
class BiometricService {
  BiometricService._();

  static final BiometricService shared = BiometricService._();
  final LocalAuthentication _auth = LocalAuthentication();

  static const String _prefKeyEnabled = 'leadx_biometric_enabled';
  static const String _prefKeyLockOnResume = 'leadx_lock_on_resume';

  bool _isBiometricEnabled = false;
  bool _lockOnResume = true;

  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get lockOnResume => _lockOnResume;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBiometricEnabled = prefs.getBool(_prefKeyEnabled) ?? false;
      _lockOnResume = prefs.getBool(_prefKeyLockOnResume) ?? true;
    } catch (_) {
      _isBiometricEnabled = false;
      _lockOnResume = true;
    }
  }

  /// Whether the device hardware supports biometrics or device credentials (PIN/pattern).
  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();
      return isSupported || canCheck || biometrics.isNotEmpty;
    } catch (e) {
      debugPrint('Biometric canAuthenticate error: $e');
      return false;
    }
  }

  /// List of enrolled biometric types (e.g. fingerprint, face, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Prompts the user with the system-native biometric dialog, returning a detailed result.
  Future<BiometricAuthResult> authenticateDetailed({
    String reason = 'Authenticate to access LeadX CRM',
  }) async {
    try {
      final can = await canAuthenticate();
      if (!can) {
        return const BiometricAuthResult(
          success: false,
          errorMessage: 'No biometric hardware or screen lock detected. Please set up a fingerprint, face, or PIN in device settings.',
        );
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      return BiometricAuthResult(
        success: authenticated,
        errorMessage: authenticated ? null : 'Authentication was cancelled or not recognized.',
      );
    } on PlatformException catch (e) {
      String message = e.message ?? e.code;
      if (e.code == 'NotEnrolled') {
        message = 'No fingerprint or lock credentials enrolled. Please enroll in device settings.';
      } else if (e.code == 'PasscodeNotSet') {
        message = 'Device lock is not set. Please set a screen lock PIN in device settings.';
      } else if (e.code == 'LockedOut') {
        message = 'Biometrics locked temporarily due to too many attempts. Please try again shortly.';
      } else if (e.code == 'PermanentlyLockedOut') {
        message = 'Biometrics locked. Please unlock using your phone PIN or password.';
      }
      return BiometricAuthResult(success: false, errorMessage: message);
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Authentication error: $e',
      );
    }
  }

  /// Prompts the user with the system-native biometric dialog, returning true on success.
  Future<bool> authenticate({
    String reason = 'Authenticate to access LeadX CRM',
  }) async {
    final result = await authenticateDetailed(reason: reason);
    return result.success;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _isBiometricEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
  }

  Future<void> setLockOnResume(bool enabled) async {
    _lockOnResume = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyLockOnResume, enabled);
  }
}

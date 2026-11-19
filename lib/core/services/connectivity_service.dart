import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Real-time network reachability monitor for LeadX.
///
/// Exposes [isOnline] and [isOffline] flags and notifies listeners when network
/// state toggles, enabling smooth floating connectivity pills and automatic
/// safe retries.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _initialized = false;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isInitialized => _initialized;

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _isOnline = true;
      _initialized = true;
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  /// Manually check connection status.
  Future<bool> check() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _isOnline;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

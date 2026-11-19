import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/app_services.dart';
import '../../core/storage/secure_token_storage.dart';
import '../../shared/models/employee.dart';

/// Owns the login session, the Sanctum token lifecycle, and the permission
/// flags the UI gates on. Exposed to the widget tree via [ChangeNotifier].
class AuthController extends ChangeNotifier {
  AuthController(this._services);

  final AppServices _services;
  ApiClient get _client => _services.apiClient;

  MeResponse? _me;
  bool _sessionActive = false;
  bool _bootstrapping = false;

  AppServices get services => _services;
  MeResponse? get me => _me;
  bool get isAuthenticated => _sessionActive && _me != null;
  bool get bootstrapping => _bootstrapping;

  int? get employeeId => _me?.data.id;

  bool get hasTeamDataAccess => _me?.hasTeamDataAccess ?? false;
  bool get canViewOrders => _me?.canViewOrders() ?? false;
  bool get canCreateOrders => _me?.canCreateOrders() ?? false;
  bool get canCompleteOrders => _me?.canCompleteOrders() ?? false;
  bool get canViewCustomers => _me?.canViewCustomers() ?? false;
  bool get canViewPayments => _me?.canViewPayments() ?? false;
  bool get canViewSubscriptions => _me?.canViewSubscriptions() ?? false;
  bool get canViewFollowUps => _me?.canViewFollowUps() ?? false;
  bool get canCreateFollowUps => _me?.canCreateFollowUps() ?? false;
  bool get canEditFollowUps => _me?.canEditFollowUps() ?? false;

  /// Restores a persisted session on cold start.
  Future<bool> restore() async {
    _bootstrapping = true;
    notifyListeners();

    final active = await SecureTokenStorage.sessionActive;
    if (!active) {
      _bootstrapping = false;
      notifyListeners();
      return false;
    }

    try {
      final res = await _client.get(ApiPaths.me);
      _me = MeResponse.fromJson(res);
      _sessionActive = true;
      _bootstrapping = false;
      notifyListeners();
      _services.startSession(_me!.data.id);
      return true;
    } on Object {
      // Token stale/revoked — clear and require login.
      await SecureTokenStorage.clear();
      _me = null;
      _sessionActive = false;
      _bootstrapping = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password, {bool remember = false}) async {
    _bootstrapping = true;
    notifyListeners();

    try {
      final res = await _client.post(ApiPaths.login, data: {
        'login': username,
        'password': password,
        if (remember) 'remember': true,
      });

      String? token = res['token'] as String?;
      if (token == null || token.isEmpty) {
        token = res['access_token'] as String?;
      }
      if ((token == null || token.isEmpty) && res['data'] is Map) {
        token = (res['data'] as Map)['token'] as String?;
      }
      if (token == null || token.isEmpty) {
        throw StateError('Login returned no token');
      }

      await SecureTokenStorage.writeToken(token);
      await SecureTokenStorage.setSessionActive(true);

      final meRes = await _client.get(ApiPaths.me);
      _me = MeResponse.fromJson(meRes);
      _sessionActive = true;
      _bootstrapping = false;
      notifyListeners();

      try {
        await _services.push.initialize();
      } catch (e) {
        if (kDebugMode) debugPrint('Push init skipped or failed: $e');
      }
      try {
        _services.startSession(_me!.data.id);
      } catch (e) {
        if (kDebugMode) debugPrint('Realtime session start failed: $e');
      }
      return true;
    } on Object {
      _bootstrapping = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiPaths.logout);
    } on Object {
      // Even if the server call fails, clear locally.
    }
    await _services.push.unregister();
    _services.stopSession();
    await SecureTokenStorage.clear();
    _me = null;
    _sessionActive = false;
    notifyListeners();
  }

  /// Force a full re-login (called from the 401 callback on the API client).
  void invalidate() {
    _me = null;
    _sessionActive = false;
    notifyListeners();
  }

  /// Refreshes the permission flags (e.g. after an admin grant change).
  Future<void> refreshMe() async {
    try {
      final res = await _client.get(ApiPaths.me);
      _me = MeResponse.fromJson(res);
      notifyListeners();
    } on Object {
      // Keep the last known identity.
    }
  }
}

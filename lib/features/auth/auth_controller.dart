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

  /// The single in-flight restore for this process. Memoizing the *future* (not
  /// just the result) means every caller — the fire-and-forget start in
  /// `main()` and the splash screen — awaits the same `GET /me` request
  /// instead of each firing its own.
  Future<bool>? _restoreFuture;

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
  ///
  /// Memoized to a single in-flight [Future] so that both `main()` (fire-and-
  /// forget) and the splash screen share one `GET /me` request instead of
  /// each firing its own. The splash still receives the result to decide
  /// whether the user lands in the shell or the login screen.
  Future<bool> restore() => _restoreFuture ??= _restoreSession();

  Future<bool> _restoreSession() async {
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
      _services.push.registerToken();
      _services.push.subscribeEmployee(_me!.data.id);
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
        await _services.push.subscribeEmployee(_me!.data.id);
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
    final empId = _me?.data.id;
    try {
      await _client.post(ApiPaths.logout);
    } on Object {
      // Even if the server call fails, clear locally.
    }
    if (empId != null) {
      await _services.push.unsubscribeEmployee(empId);
    }
    await _services.push.unregister();
    _services.stopSession();
    await SecureTokenStorage.clear();
    _me = null;
    _sessionActive = false;
    _restoreFuture = null;
    notifyListeners();
  }

  /// Force a full re-login (called from the 401 callback on the API client).
  void invalidate() {
    final empId = _me?.data.id;
    if (empId != null) {
      _services.push.unsubscribeEmployee(empId);
    }
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

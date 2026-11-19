import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/services.dart';
import '../../shared/models/currency.dart';

/// Centralized app configuration (admin currency + formatting rules).
///
/// - [currency] is the single source of truth for every financial figure:
///   the admin panel's `currency` setting, projected through
///   `GET /employee/app-config`. No screen hardcodes a symbol or code.
/// - The last successful payload is cached to [SharedPreferences] so money
///   stays correctly formatted offline / before the first refresh.
/// - [refresh] re-fetches on login and on pull-to-refresh; when the admin
///   changes the currency, the app reflects it on the next refresh.
/// - Never performs conversion: it only formats the actual currency the
///   admin system uses.
///
/// Uses the shared [ApiClient] directly (not [AppServices]) so it has no
/// dependency on FCM/Reverb and stays cheap to construct in tests.
class AppConfigService extends ChangeNotifier {
  AppConfigService();

  final LeadxApi _api = LeadxApi(ApiClient.shared);
  final String _cacheKey = 'leadx.app_config.v1';
  final String _logoCacheKey = 'leadx.site_logo.v1';

  CurrencyConfig _currency = CurrencyConfig.fallback;
  String? _siteLogoUrl;
  String _siteName = 'LeadX';
  bool _loading = false;

  CurrencyConfig get currency => _currency;
  String? get siteLogoUrl => _siteLogoUrl;
  String get siteName => _siteName;
  bool get isLoaded => _loading == false;

  /// Read the cached config (offline display). Call once at startup;
  /// subsequent calls resolve instantly from the in-memory copy.
  Future<void> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _currency = CurrencyConfig.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
      } on Object {
        // Corrupt cache — keep the safe fallback.
      }
    }
    _siteLogoUrl = prefs.getString(_logoCacheKey) ??
        'https://leadx.cloudaspiresolutions.in/uploads/branding/logo_1794987898_hYJudvzk.png';
    notifyListeners();
  }

  /// Fetch the live config from the backend and persist it.
  ///
  /// Idempotent + cheap; safe to call on every login and on dashboard
  /// pull-to-refresh. Errors never throw — the last known good config
  /// (or fallback) remains active so the UI keeps formatting money.
  Future<bool> refresh() async {
    if (_loading) return false;
    _loading = true;
    try {
      final res = await _api.appConfig();
      final data = res['data'] as Map<String, dynamic>?;
      final next = CurrencyConfig.fromJson(data);
      _currency = next;

      final serverLogo = data?['site_logo'] as String? ??
          data?['logo_url'] as String? ??
          data?['site_logo_url'] as String?;
      if (serverLogo != null && serverLogo.isNotEmpty) {
        _siteLogoUrl = serverLogo;
      } else {
        _siteLogoUrl ??=
            'https://leadx.cloudaspiresolutions.in/uploads/branding/logo_1794987898_hYJudvzk.png';
      }

      final serverName = data?['site_name'] as String?;
      if (serverName != null && serverName.isNotEmpty) {
        _siteName = serverName;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(next.toMap()));
      if (_siteLogoUrl != null) {
        await prefs.setString(_logoCacheKey, _siteLogoUrl!);
      }
      notifyListeners();
      return true;
    } on Object {
      // Network / auth hiccup: keep the cached currency & logo.
      return false;
    } finally {
      _loading = false;
    }
  }

  /// Convenience for widgets: `Money.format(context, 1234.5)` resolves the
  /// [CurrencyConfig] from the provider tree and formats in one call.
  /// Also exposed statically as [CurrencyFormatter].
  static String money(BuildContext context, num? value, {String? code}) {
    final cfg = context.read<AppConfigService>().currency;
    return cfg.format(value, code: code);
  }
}

/// Static façade so call sites that don't have a [BuildContext] (or that
/// already hold a [CurrencyConfig]) format through the one central place.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String money(CurrencyConfig cfg, num? value, {String? code}) =>
      cfg.format(value, code: code);

  /// Watch the [AppConfigService] and return a formatted amount, rebuilding
  /// when the admin currency changes.
  static String context(BuildContext context, num? value, {String? code}) {
    final cfg = context.watch<AppConfigService>().currency;
    return cfg.format(value, code: code);
  }
}

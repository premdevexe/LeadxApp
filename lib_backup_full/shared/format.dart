import 'package:intl/intl.dart';

import 'models/currency.dart';

/// Display helpers. The backend sends ISO-8601 datetimes and raw numbers;
/// these shape them for the UI.
///
/// Money formatting is the single source of truth for every financial figure:
/// it always formats through the live [CurrencyConfig] bound by
/// [bindLiveCurrency] (the admin panel's currency, fetched from
/// `GET /employee/app-config`). No symbol or code is hardcoded here — the
/// previous `₹` default is gone.
class Fmt {
  Fmt._();

  /// The active currency + formatting rules. Defaults to the safe neutral
  /// [CurrencyConfig.fallback] (matching the backend's USD default) until the
  /// app config is fetched; [bindLiveCurrency] keeps it in step with the admin.
  static CurrencyConfig live = CurrencyConfig.fallback;

  /// Point [Fmt] at a freshly loaded [CurrencyConfig] (called at startup from
  /// the cache and on every admin-currency refresh).
  static void bindLiveCurrency(CurrencyConfig cfg) => live = cfg;

  /// Format a raw amount in the active admin currency.
  static String money(dynamic value) => live.format(_toNum(value));

  /// Format a raw amount in a specific currency [code] (e.g. a payment row's
  /// own currency), resolved through the admin's symbol catalogue.
  static String moneyFor(dynamic value, {String? code}) =>
      live.format(_toNum(value), code: code);

  static num _toNum(dynamic value) => (value is num)
      ? value
      : (value is String ? (num.tryParse(value) ?? 0) : 0);

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  /// "Mar 3, 2026, 04:12 PM"
  static String dateTime(String? iso) {
    final d = _parse(iso);
    if (d == null) return '—';
    return DateFormat('MMM d, y, h:mm a').format(d);
  }

  /// "Mar 3, 2026"
  static String date(String? iso) {
    final d = _parse(iso);
    if (d == null) return '—';
    return DateFormat('MMM d, y').format(d);
  }

  /// "04:12 PM"
  static String time(String? iso) {
    final d = _parse(iso);
    if (d == null) return '—';
    return DateFormat('h:mm a').format(d);
  }

  /// Relative "2 days from now" / "3 days ago".
  static String relative(String? iso) {
    final d = _parse(iso);
    if (d == null) return '—';
    final now = DateTime.now();
    final diff = d.difference(now);
    final days = diff.inDays.abs();
    if (days == 0) {
      final hrs = diff.inHours.abs();
      if (hrs == 0) return diff.isNegative ? 'in a few minutes' : 'a few minutes ago';
      return diff.isNegative ? 'in $hrs hr${hrs == 1 ? '' : 's'}' : '$hrs hr${hrs == 1 ? '' : 's'} ago';
    }
    if (days == 1) return diff.isNegative ? 'tomorrow' : 'yesterday';
    return diff.isNegative ? 'in $days days' : '$days days ago';
  }

  static String statusLabel(String? raw) =>
      (raw ?? '').trim().isEmpty ? '—' : raw!.trim().split('_').join(' ').toUpperCase();

  /// Compact "Mar 2026" for chart labels.
  static String monthLabel(String? iso) {
    final d = _parse(iso);
    if (d == null) return '—';
    return DateFormat('MMM yyyy').format(d);
  }
}

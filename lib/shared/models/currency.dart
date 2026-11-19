/// The active currency + formatting rules, projected from the admin panel's
/// `currency` setting through `GET /employee/app-config`. This is the single
/// source of truth for every financial figure in the app — no screen may
/// hardcode a symbol, code, or precision.
class CurrencyConfig {
  final String code;
  final String symbol;

  /// 2 in the current admin convention.
  final int decimalPlaces;

  /// `before` (default: `₹1,234.00`) or `after` (`1,234.00 ₽`).
  final String symbolPosition;
  final String thousandsSeparator;
  final String decimalSeparator;

  /// Every currency the admin can select, `code -> symbol`. Used to resolve
  /// a payment row's own `currency` code (legacy rows may predate a change).
  final Map<String, String> codes;

  final String siteName;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.decimalPlaces,
    required this.symbolPosition,
    required this.thousandsSeparator,
    required this.decimalSeparator,
    required this.codes,
    this.siteName = 'LeadX',
  });

  /// The safe neutral default — matches the backend's `USD` default so the
  /// app never invents a symbol on its own.
  static const CurrencyConfig fallback = CurrencyConfig(
    code: 'USD',
    symbol: r'$',
    decimalPlaces: 2,
    symbolPosition: 'before',
    thousandsSeparator: ',',
    decimalSeparator: '.',
    codes: {'INR': r'₹', 'USD': r'$', 'EUR': r'€', 'GBP': r'£', 'AED': 'د.إ'},
  );

  /// Parse the `data` block of `GET /employee/app-config`. Returns
  /// [fallback] for an empty document so the app always has a safe
  /// neutral currency (matching the backend's `USD` default) — it never
  /// invents a symbol on its own.
  factory CurrencyConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['currency'] is! Map) return fallback;
    final c = (json['currency'] as Map).cast<String, dynamic>();
    final rawCodes = json['currencies'] is Map ? json['currencies'] as Map : {};
    final rawSymbol = c['symbol'] as String?;
    return CurrencyConfig(
      code: c['code'] as String? ?? fallback.code,
      symbol: (rawSymbol != null && rawSymbol.isNotEmpty)
          ? rawSymbol
          : fallback.symbol,
      decimalPlaces: (c['decimal_places'] as num?)?.toInt() ?? fallback.decimalPlaces,
      symbolPosition: c['symbol_position'] as String? ?? fallback.symbolPosition,
      thousandsSeparator:
          c['thousands_separator'] as String? ?? fallback.thousandsSeparator,
      decimalSeparator: c['decimal_separator'] as String? ?? fallback.decimalSeparator,
      codes: rawCodes.map((k, v) => MapEntry(k.toString(), v.toString())),
      siteName: json['site_name'] as String? ?? fallback.siteName,
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'symbol': symbol,
        'decimal_places': decimalPlaces,
        'symbol_position': symbolPosition,
        'thousands_separator': thousandsSeparator,
        'decimal_separator': decimalSeparator,
        'currencies': codes,
        'site_name': siteName,
      };

  /// The symbol that applies to a row carrying its own currency [code]
  /// (e.g. a payment), falling back to the active [symbol].
  String symbolForCode(String? code) {
    if (code == null || code.isEmpty) return symbol;
    return codes[code] ?? symbol;
  }

  /// Format a raw amount using this config. [code] optionally re-points at a
  /// different symbol (per-row currency). Mirrors the admin/web convention:
  /// symbol + thousands-grouped + `decimalPlaces` decimals.
  String format(num? value, {String? code}) {
    final v = (value ?? 0).abs();
    final scaled = v.toStringAsFixed(decimalPlaces);
    final parts = scaled.split('.');
    final intPart = _group(parts[0]);
    final decPart = decimalSeparator.isEmpty ? '' : (parts.length > 1 ? decimalSeparator + parts[1] : '');
    final body = intPart + decPart;
    final sym = code == null ? symbol : symbolForCode(code);
    if (symbolPosition == 'after') {
      return '$body $sym'.trim();
    }
    final negative = (value ?? 0) < 0;
    final sign = negative ? '-' : '';
    return '$sign$sym$body';
  }

  String _group(String digits) {
    if (thousandsSeparator.isEmpty) return digits;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write(thousandsSeparator);
    }
    return buf.toString();
  }
}

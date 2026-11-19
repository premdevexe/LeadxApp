import 'package:flutter/material.dart';

/// Central design tokens. Every screen reads color through these or through
/// the [ColorScheme] of the active theme — never through raw `Colors.*`
/// shades, so light/dark stay consistent.
class AppColors {
  AppColors._();

  // ── Spacing (4px grid) ─────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // ── Radii (web tokens: sm/md/lg/xl) ────────────────────────────────
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  // Brand — near-black (#171717) in light mode; the dark-mode accent is
  // neutral-50 (#FAFAFA) on near-black surfaces, matching the web palette.
  static const Color brand = Color(0xFF171717);
  static const Color brandDark = Color(0xFFFAFAFA);
  // Web secondary accent: indigo-600 (#4F46E5).
  static const Color emeraldAccent = Color(0xFF4F46E5);

  // Semantic (light-mode shades from the web tokens; 4xx–5xx shades
  // read on dark surfaces).
  static const Color successLight = Color(0xFF15803D);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warningLight = Color(0xFFD97706);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerLight = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color infoLight = Color(0xFF2563EB);
  static const Color infoDark = Color(0xFF93C5FD);

  // Tint pairs for flat SaaS status chips / pills: a soft 5xx background
  // with a readable 8xx ink (web Tailwind shades). The dark-mode tint is
  // the same hue at a low alpha so it stays quiet on near-black surfaces.
  static const Color successTintLight = Color(0xFFF0FDF4); // green-50
  static const Color successTintDark = Color(0x1F4ADE80);
  static const Color successInkLight = Color(0xFF166534); // green-800
  static const Color successInkDark = Color(0xFF4ADE80);
  static const Color warningTintLight = Color(0xFFFEF3C7); // amber-50
  static const Color warningTintDark = Color(0x1FFBBF24);
  static const Color warningInkLight = Color(0xFF92400E); // amber-800
  static const Color warningInkDark = Color(0xFFFBBF24);
  static const Color dangerTintLight = Color(0xFFFEE2E2); // red-50
  static const Color dangerTintDark = Color(0x1FF87171);
  static const Color dangerInkLight = Color(0xFF991B1B); // red-800
  static const Color dangerInkDark = Color(0xFFF87171);
  static const Color infoTintLight = Color(0xFFEFF6FF); // blue-50
  static const Color infoTintDark = Color(0x1F93C5FD);
  static const Color infoInkLight = Color(0xFF1E40AF); // blue-800
  static const Color infoInkDark = Color(0xFF93C5FD);
  // App backgrounds (web: neutral-50 light, near-black dark).
  static const Color neutralBgLight = Color(0xFFFAFAFA);
  static const Color neutralBgDark = Color(0xFF1C1C1C);

  // Elevated content surfaces (white on light; neutral-800 on dark).
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedDark = Color(0xFF262626);
}

/// A tinted chip surface pair: a soft 5xx background with a readable 8xx
/// ink, matching the web status pill colours.
class StatusTint {
  const StatusTint({required this.bg, required this.ink});

  final Color bg;
  final Color ink;
}

/// Semantic status palettes that work on both themes. Pass the active
/// [ColorScheme]'s brightness.
class StatusPalette {
  StatusPalette._();

  static Color success(ColorScheme cs) =>
      cs.brightness == Brightness.dark ? AppColors.successDark : AppColors.successLight;
  static Color warning(ColorScheme cs) =>
      cs.brightness == Brightness.dark ? AppColors.warningDark : AppColors.warningLight;
  static Color danger(ColorScheme cs) =>
      cs.brightness == Brightness.dark ? AppColors.dangerDark : AppColors.dangerLight;
  static Color info(ColorScheme cs) =>
      cs.brightness == Brightness.dark ? AppColors.infoDark : AppColors.infoLight;

  /// Tinted pill pairs (5xx bg + 8xx ink) for flat status chips, mapped
  /// to the web status colours. Dark mode uses the same hue at a low
  /// alpha so pills stay quiet on near-black surfaces.
  static StatusTint successTint(ColorScheme cs) => StatusTint(
        bg: cs.brightness == Brightness.dark
            ? AppColors.successTintDark
            : AppColors.successTintLight,
        ink: cs.brightness == Brightness.dark
            ? AppColors.successInkDark
            : AppColors.successInkLight,
      );
  static StatusTint warningTint(ColorScheme cs) => StatusTint(
        bg: cs.brightness == Brightness.dark
            ? AppColors.warningTintDark
            : AppColors.warningTintLight,
        ink: cs.brightness == Brightness.dark
            ? AppColors.warningInkDark
            : AppColors.warningInkLight,
      );
  static StatusTint dangerTint(ColorScheme cs) => StatusTint(
        bg: cs.brightness == Brightness.dark
            ? AppColors.dangerTintDark
            : AppColors.dangerTintLight,
        ink: cs.brightness == Brightness.dark
            ? AppColors.dangerInkDark
            : AppColors.dangerInkLight,
      );
  static StatusTint infoTint(ColorScheme cs) => StatusTint(
        bg: cs.brightness == Brightness.dark
            ? AppColors.infoTintDark
            : AppColors.infoTintLight,
        ink: cs.brightness == Brightness.dark
            ? AppColors.infoInkDark
            : AppColors.infoInkLight,
      );

  /// Neutral (unrecognised status) pill: quiet grey tint + secondary ink.
  static StatusTint neutralTint(ColorScheme cs) => StatusTint(
        bg: cs.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF5F5F5),
        ink: cs.onSurfaceVariant,
      );

  /// Maps a raw status string to its pill tint (mirrors the status-color
  /// mapping used by [StatusChip]); unknown values get the neutral tint.
  static StatusTint tintOf(ColorScheme cs, String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'confirmed':
      case 'completed':
      case 'active':
      case 'verified':
      case 'paid':
      case 'synced':
      case 'fixed':
        return successTint(cs);
      case 'pending':
      case 'scheduled':
      case 'partially_paid':
      case 'still_facing':
      case 'rescheduled':
      case 'expiring':
      case 'error':
        return warningTint(cs);
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'refunded':
      case 'expired':
      case 'deleted':
        return dangerTint(cs);
      case 'in_progress':
      case 'new':
        return infoTint(cs);
      default:
        return neutralTint(cs);
    }
  }
}

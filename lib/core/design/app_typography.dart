import 'package:flutter/material.dart';

/// Centralized typography: Inter (bundled — the LeadX web UI face, OFL
/// licensed), the spec's six tiers, and
/// [bodyNumeric] / [statNumeric] for tabular figures on money + statistics.
///
/// Every screen styles text through [textTheme] (via the app [ThemeData])
/// or through these helpers — no hand-rolled `TextStyle(fontSize: 12)` for
/// the standard tiers. System text scaling is honoured automatically because
/// the styles live on the [TextTheme] (Material applies the text scaler to
/// `MaterialApp` text via `TextTheme` resolution).
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  /// Display: 28–32px bold (splash, large KPIs).
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Page title: 22–26px semibold.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  /// Section title: 18–20px semibold.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  /// Card title: 15–17px medium.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  /// Body: 16px regular (web body size), roomy line height.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  /// Secondary text: 12–13px.
  static const TextStyle secondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Caption: 11–12px.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Money + statistics: body tier with tabular figures (no reflow as
  /// numbers change) and semibold weight.
  static const TextStyle statNumeric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Compact numeric for inline list rows (order/pay rows, chart captions).
  /// Smaller than [statNumeric] but still tabular so figures don't reflow.
  static const TextStyle statNumericSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Label tier (15px medium) used by tab bars and dense controls.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  /// Maps the tiers onto [TextTheme] slots so every Material widget
  /// (buttons, list tiles, app bars…) inherits Inter + the hierarchy.
  static TextTheme textTheme() => const TextTheme(
        displayLarge: display,
        displayMedium: TextStyle(
          fontFamily: fontFamily, fontSize: 26, height: 1.2,
          fontWeight: FontWeight.w700, letterSpacing: -0.4,
        ),
        headlineMedium: pageTitle,
        headlineSmall: sectionTitle,
        titleLarge: sectionTitle,
        titleMedium: cardTitle,
        titleSmall: cardTitle,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: secondary,
        labelLarge: TextStyle(
          fontFamily: fontFamily, fontSize: 15, height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: secondary,
        labelSmall: caption,
      );

  /// Tabular figures helper for ad-hoc numeric [TextStyle] copies.
  static List<FontFeature> get tabularFigures => [FontFeature.tabularFigures()];
}

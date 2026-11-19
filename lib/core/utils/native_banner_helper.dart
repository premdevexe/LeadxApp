import 'package:flutter/material.dart';
import 'package:veneer/veneer.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// Shows an iOS 26 Liquid Glass native notification banner above the app chrome.
/// If running on Android or older iOS where native banners are unavailable,
/// falls back to a clean, quiet [SnackBar].
Future<void> showLeadxBanner(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? body,
  NativeIcon? icon,
  VoidCallback? onTap,
}) async {
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;

  final shown = await showNativeBanner(
    title: title,
    subtitle: subtitle,
    body: body,
    icon: icon ?? const NativeIcon.symbol('bell.fill', fallback: Icons.notifications),
    style: NativeBannerStyle(
      dark: isDark,
      tint: cs.primary.withValues(alpha: 0.15),
      titleStyle: AppTypography.cardTitle.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      subtitleStyle: AppTypography.caption.copyWith(
        color: cs.onSurfaceVariant,
      ),
      bodyStyle: AppTypography.body.copyWith(
        color: cs.onSurface,
        fontSize: 13,
      ),
    ),
    onTap: onTap,
  );

  if (!shown && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body != null)
              Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
      ),
    );
  }
}

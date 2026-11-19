import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/native_chrome.dart' show NativeIcon;

/// Shows a quiet [SnackBar] banner.
///
/// The iOS-26 native banner chrome is retired; every call site now gets a
/// clean, solid [SnackBar] with the same title / subtitle / body content.
/// The [icon] and [onTap] are accepted for call-site compatibility — the
/// solid snackbar simply ignores them.
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

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          if (body != null)
            Text(body, style: const TextStyle(fontSize: 12)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor:
          isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
    ),
  );
}

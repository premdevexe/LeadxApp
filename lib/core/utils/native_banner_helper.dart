import 'package:flutter/material.dart';

import '../../shared/widgets/app_snackbar.dart';
import '../design/native_chrome.dart' show NativeIcon;

/// Shows a quiet [SnackBar] banner using [AppSnackBar].
///
/// Every call site gets a clean, solid floating [SnackBar] adhering to the Material UI specification.
Future<void> showLeadxBanner(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? body,
  NativeIcon? icon,
  VoidCallback? onTap,
}) async {
  if (!context.mounted) return;

  final message = subtitle ?? body ?? '';
  AppSnackBar.show(
    context,
    title: title,
    message: message,
    type: AppSnackBarType.neutral,
    onAction: onTap,
    actionLabel: onTap != null ? 'View' : null,
  );
}

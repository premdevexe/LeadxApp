import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// Centralized native sensory feedback and platform-adaptive dialog helpers.
class NativeFeedback {
  NativeFeedback._();

  /// Subtle click feedback for tab switching and pill selections.
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Gentle tactile bump for buttons, switches, and cards.
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Firmer bump for primary submissions and completions.
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Success pattern for completed actions (e.g. order saved, issue resolved).
  static void success() {
    HapticFeedback.lightImpact();
  }

  /// Alert pattern for errors or validation denials.
  static void error() {
    HapticFeedback.heavyImpact();
  }

  /// Shows a platform-adaptive confirmation dialog (Cupertino on iOS, Material 3 on Android).
  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    light();
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;

    if (isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final cs = theme.colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        title: Text(title, style: AppTypography.cardTitle),
        content: Text(message, style: AppTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

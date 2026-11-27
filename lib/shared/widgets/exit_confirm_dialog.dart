import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/utils/native_feedback.dart';

/// A modal confirmation dialog prompting the user before exiting the application.
///
/// Designed to follow the LeadX SaaS visual language with an icon badge, clear
/// typography, and platform-adaptive buttons.
class ExitConfirmationDialog extends StatelessWidget {
  const ExitConfirmationDialog({
    super.key,
    this.title = 'Exit LeadX?',
    this.message = 'Are you sure you want to close and exit the application?',
    this.confirmLabel = 'Exit App',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Presents the exit confirmation dialog and returns `true` if the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    String title = 'Exit LeadX?',
    String message = 'Are you sure you want to close and exit the application?',
    String confirmLabel = 'Exit App',
    String cancelLabel = 'Cancel',
  }) async {
    NativeFeedback.light();
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;

    if (isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ExitConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }

  /// Shows the confirmation dialog and, if confirmed, immediately exits the app via [SystemNavigator.pop].
  static Future<bool> showAndExit(
    BuildContext context, {
    String title = 'Exit LeadX?',
    String message = 'Are you sure you want to close and exit the application?',
  }) async {
    final confirmed = await show(
      context,
      title: title,
      message: message,
    );

    if (confirmed) {
      NativeFeedback.medium();
      await SystemNavigator.pop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: BorderSide(
          color: isDark
              ? cs.outlineVariant.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon badge with danger tint
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dangerTintDark : AppColors.dangerTintLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 28,
                color: isDark ? AppColors.dangerDark : AppColors.dangerLight,
              ),
            ),
          ),
          const SizedBox(height: AppColors.space4),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppColors.space2),
          // Subtitle / message
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.secondary.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          onPressed: () {
            NativeFeedback.light();
            Navigator.of(context).pop(false);
          },
          child: Text(
            cancelLabel,
            style: AppTypography.secondary.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppColors.dangerDark : AppColors.dangerLight,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
          ),
          onPressed: () {
            NativeFeedback.medium();
            Navigator.of(context).pop(true);
          },
          child: Text(
            confirmLabel,
            style: AppTypography.secondary.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// A wrapper widget that captures the Android / system back button press
/// and prompts the user with [ExitConfirmationDialog].
class ExitConfirmScope extends StatelessWidget {
  const ExitConfirmScope({
    super.key,
    required this.child,
    this.enabled = true,
    this.onBackNonRoot,
  });

  final Widget child;
  final bool enabled;

  /// Optional callback invoked when back is pressed but the screen is not at root
  /// (e.g. switching back to tab 0 instead of exiting). If it returns true, exit is prevented.
  final bool Function()? onBackNonRoot;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !enabled) return;

        if (onBackNonRoot != null && onBackNonRoot!()) {
          return;
        }

        await ExitConfirmationDialog.showAndExit(context);
      },
      child: child,
    );
  }
}

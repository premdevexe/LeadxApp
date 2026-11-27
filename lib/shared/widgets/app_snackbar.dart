import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/utils/native_feedback.dart';

/// Semantic types for [AppSnackBar] alerts and feedback.
enum AppSnackBarType {
  /// Standard informational notification (default blue tint).
  info,

  /// Positive confirmation for completed actions (green tint).
  success,

  /// Advisory notice or non-fatal issue (amber tint).
  warning,

  /// Critical failure or validation rejection (red tint).
  error,

  /// Subtle neutral feedback matching the theme surface.
  neutral,
}

/// A comprehensive Material UI [SnackBar] component implementing the official
/// Flutter Material SnackBar specification (https://pub.dev/documentation/material_ui/latest/material_ui/SnackBar-class.html)
/// tailored for the LeadX design system.
///
/// Supports floating cards, status iconography, action buttons, close icons,
/// custom titles/subtitles, haptic feedback, and static convenience triggers.
class AppSnackBar {
  AppSnackBar._();

  /// Global messenger key so snackbars can be presented across contexts.
  static GlobalKey<ScaffoldMessengerState>? messengerKey;

  /// Creates a standard Material [SnackBar] instance configured with LeadX styling.
  static SnackBar create({
    required BuildContext context,
    required String message,
    String? title,
    Widget? customContent,
    AppSnackBarType type = AppSnackBarType.neutral,
    IconData? icon,
    bool showIcon = true,
    SnackBarAction? action,
    String? actionLabel,
    VoidCallback? onAction,
    Color? actionTextColor,
    bool showCloseIcon = true,
    Color? closeIconColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: AppColors.space4,
      vertical: AppColors.space3,
    ),
    double? width,
    double elevation = 4.0,
    ShapeBorder? shape,
    Color? backgroundColor,
    Color? foregroundColor,
    DismissDirection dismissDirection = DismissDirection.horizontal,
    VoidCallback? onVisible,
    Clip clipBehavior = Clip.hardEdge,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Resolve semantic colors based on type
    final resolvedColors = _resolveColors(
      type: type,
      cs: cs,
      isDark: isDark,
      customBg: backgroundColor,
      customFg: foregroundColor,
    );

    final resolvedIcon = icon ?? _resolveDefaultIcon(type);

    final resolvedShape = shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: BorderSide(
            color: isDark
                ? cs.outlineVariant.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        );

    final resolvedMargin = behavior == SnackBarBehavior.floating
        ? (margin ??
            const EdgeInsets.symmetric(
              horizontal: AppColors.space4,
              vertical: AppColors.space3,
            ))
        : null;

    final resolvedAction = action ??
        (actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: actionTextColor ?? resolvedColors.actionColor,
                onPressed: () {
                  NativeFeedback.light();
                  onAction();
                },
              )
            : null);

    final contentWidget = customContent ??
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showIcon && resolvedIcon != null) ...[
              Container(
                padding: const EdgeInsets.all(AppColors.space2),
                decoration: BoxDecoration(
                  color: resolvedColors.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolvedIcon,
                  size: 20,
                  color: resolvedColors.iconColor,
                ),
              ),
              const SizedBox(width: AppColors.space3),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: resolvedColors.foregroundColor,
                      ),
                    ),
                  Text(
                    message,
                    style: AppTypography.secondary.copyWith(
                      color: resolvedColors.foregroundColor.withValues(
                        alpha: title != null ? 0.85 : 1.0,
                      ),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

    return SnackBar(
      content: contentWidget,
      backgroundColor: resolvedColors.backgroundColor,
      elevation: elevation,
      margin: resolvedMargin,
      padding: padding,
      width: width,
      shape: resolvedShape,
      behavior: behavior,
      action: resolvedAction,
      showCloseIcon: showCloseIcon,
      closeIconColor: closeIconColor ??
          resolvedColors.foregroundColor.withValues(alpha: 0.6),
      duration: duration,
      dismissDirection: dismissDirection,
      onVisible: onVisible,
      clipBehavior: clipBehavior,
    );
  }

  /// Displays the configured SnackBar on the current [ScaffoldMessenger].
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    String? title,
    Widget? customContent,
    AppSnackBarType type = AppSnackBarType.neutral,
    IconData? icon,
    bool showIcon = true,
    SnackBarAction? action,
    String? actionLabel,
    VoidCallback? onAction,
    Color? actionTextColor,
    bool showCloseIcon = true,
    Color? closeIconColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: AppColors.space4,
      vertical: AppColors.space3,
    ),
    double? width,
    double elevation = 4.0,
    ShapeBorder? shape,
    Color? backgroundColor,
    Color? foregroundColor,
    DismissDirection dismissDirection = DismissDirection.horizontal,
    VoidCallback? onVisible,
    Clip clipBehavior = Clip.hardEdge,
  }) {
    // Provide appropriate haptic feedback for the event
    switch (type) {
      case AppSnackBarType.success:
        NativeFeedback.success();
        break;
      case AppSnackBarType.error:
        NativeFeedback.error();
        break;
      case AppSnackBarType.warning:
      case AppSnackBarType.info:
      case AppSnackBarType.neutral:
        NativeFeedback.light();
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final snackBar = create(
      context: context,
      message: message,
      title: title,
      customContent: customContent,
      type: type,
      icon: icon,
      showIcon: showIcon,
      action: action,
      actionLabel: actionLabel,
      onAction: onAction,
      actionTextColor: actionTextColor,
      showCloseIcon: showCloseIcon,
      closeIconColor: closeIconColor,
      duration: duration,
      behavior: behavior,
      margin: margin,
      padding: padding,
      width: width,
      elevation: elevation,
      shape: shape,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      dismissDirection: dismissDirection,
      onVisible: onVisible,
      clipBehavior: clipBehavior,
    );

    return messenger.showSnackBar(snackBar);
  }

  /// Convenience shortcut for success notifications.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSuccess(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: AppSnackBarType.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience shortcut for error notifications.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showError(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: AppSnackBarType.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience shortcut for warning notifications.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showWarning(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: AppSnackBarType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Convenience shortcut for informative notifications.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showInfo(
    BuildContext context,
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: AppSnackBarType.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Hides the currently visible [SnackBar].
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Clears all queued and active [SnackBar]s.
  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Helper to resolve icon based on type.
  static IconData? _resolveDefaultIcon(AppSnackBarType type) {
    switch (type) {
      case AppSnackBarType.success:
        return Icons.check_circle_rounded;
      case AppSnackBarType.error:
        return Icons.error_rounded;
      case AppSnackBarType.warning:
        return Icons.warning_amber_rounded;
      case AppSnackBarType.info:
        return Icons.info_outline_rounded;
      case AppSnackBarType.neutral:
        return null;
    }
  }

  /// Resolves colors adhering to LeadX theme and WCAG contrast.
  static _SnackBarColors _resolveColors({
    required AppSnackBarType type,
    required ColorScheme cs,
    required bool isDark,
    Color? customBg,
    Color? customFg,
  }) {
    final defaultBg =
        isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final defaultFg = isDark ? Colors.white : const Color(0xFF171717);

    Color bg = customBg ?? defaultBg;
    Color fg = customFg ?? defaultFg;
    Color iconColor;
    Color iconBgColor;
    Color actionColor;

    switch (type) {
      case AppSnackBarType.success:
        iconColor = isDark ? AppColors.successDark : AppColors.successLight;
        iconBgColor = isDark
            ? AppColors.successTintDark
            : AppColors.successTintLight;
        actionColor = isDark ? AppColors.successDark : AppColors.successLight;
        break;
      case AppSnackBarType.error:
        iconColor = isDark ? AppColors.dangerDark : AppColors.dangerLight;
        iconBgColor = isDark
            ? AppColors.dangerTintDark
            : AppColors.dangerTintLight;
        actionColor = isDark ? AppColors.dangerDark : AppColors.dangerLight;
        break;
      case AppSnackBarType.warning:
        iconColor = isDark ? AppColors.warningDark : AppColors.warningLight;
        iconBgColor = isDark
            ? AppColors.warningTintDark
            : AppColors.warningTintLight;
        actionColor = isDark ? AppColors.warningDark : AppColors.warningLight;
        break;
      case AppSnackBarType.info:
        iconColor = isDark ? AppColors.infoDark : AppColors.infoLight;
        iconBgColor = isDark
            ? AppColors.infoTintDark
            : AppColors.infoTintLight;
        actionColor = isDark ? AppColors.infoDark : AppColors.infoLight;
        break;
      case AppSnackBarType.neutral:
        iconColor = fg;
        iconBgColor = fg.withValues(alpha: 0.08);
        actionColor = isDark ? AppColors.brandDark : cs.primary;
        break;
    }

    return _SnackBarColors(
      backgroundColor: bg,
      foregroundColor: fg,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      actionColor: actionColor,
    );
  }
}

class _SnackBarColors {
  const _SnackBarColors({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconColor,
    required this.iconBgColor,
    required this.actionColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color iconColor;
  final Color iconBgColor;
  final Color actionColor;
}

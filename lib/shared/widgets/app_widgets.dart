import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/services/app_config_service.dart';
import '../format.dart';
import '../models/subscription.dart' show ListMeta;

export 'app_snackbar.dart';
export 'exit_confirm_dialog.dart';

/// Small, reusable UI pieces shared across feature screens.
///
/// Content surfaces are flat SaaS cards: solid white (light) / near-black
/// (dark) with a 1px hairline border and a subtle shadow, on a #FAFAFA
/// app background.

class AppCard {
  const AppCard._();

  /// A flat SaaS card — white (light) or near-black (dark) surface, 1px
  /// hairline border, subtle 0 1px 2px shadow.
  static BoxDecoration decorationOf(
    BuildContext context, {
    Color? color,
    double radius = AppColors.radiusLg,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? cs.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? cs.outlineVariant.withValues(alpha: 0.3)
            : cs.outlineVariant.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: isDark
          ? const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              )
            ]
          : const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
    );
  }

  /// A rounded content surface with an optional tap target.
  static Widget surface(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    Color? color,
    VoidCallback? onTap,
    double radius = AppColors.radiusLg,
  }) {
    final shape = BorderRadius.circular(radius);
    final ink = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Padding(padding: padding, child: child),
      ),
    );
    return Container(
      margin: margin,
      decoration: decorationOf(context, color: color, radius: radius),
      child: ink,
    );
  }

  /// Compact stat tile: a label, one figure and an optional change line.
  /// Compact stat tile: an optional icon medallion + label, one figure in
  /// tabular figures, an optional change line. [color] tints the accent.
  static Widget stat(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    Color? color,
    VoidCallback? onTap,
    String? subtitle,
    Widget? badge,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = color ?? (isDark ? AppColors.brandDark : AppColors.brand);
    return surface(
      context,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Center(
                    child: Icon(icon, size: 15, color: accent),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                badge
              else if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.statNumeric.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A section header with an optional trailing action (e.g. "View all").
  static Widget section(
    BuildContext context,
    String title, {
    Widget? trailing,
    double top = AppColors.space4,
    double bottom = AppColors.space2,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: top, horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Text(title,
                  style: AppTypography.sectionTitle.copyWith(color: cs.onSurface)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child:
                  Icon(icon ?? Icons.inbox_outlined, size: 28, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style:
                  AppTypography.cardTitle.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel ?? 'Go')),
            ],
          ],
        ),
      ),
    );
  }
}

class LeadxFlickrLoading extends StatelessWidget {
  const LeadxFlickrLoading({
    super.key,
    this.size = 40,
    this.leftDotColor = const Color(0xFF0063DC),
    this.rightDotColor = const Color(0xFFFF0084),
  });

  final double size;
  final Color leftDotColor;
  final Color rightDotColor;

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.flickr(
      leftDotColor: leftDotColor,
      rightDotColor: rightDotColor,
      size: size,
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingAnimationWidget.flickr(
            leftDotColor: const Color(0xFF0063DC),
            rightDotColor: const Color(0xFFFF0084),
            size: 44,
          ),
          const SizedBox(height: 20),
          Text(message, style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = StatusPalette.dangerTint(cs);
    return AppCard.surface(
      context,
      color: tint.bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.all(4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: tint.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.secondary.copyWith(color: tint.ink),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: tint.ink),
              child: Text('Retry',
                  style: AppTypography.secondary.copyWith(
                      color: tint.ink, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Maps a status string to a theme-safe accent colour for chips + dots.
Color statusColorOf(BuildContext context, String raw) {
  final cs = Theme.of(context).colorScheme;
  switch (raw.trim().toLowerCase()) {
    case 'confirmed':
    case 'completed':
    case 'active':
    case 'verified':
    case 'paid':
    case 'synced':
    case 'fixed':
      return StatusPalette.success(cs);
    case 'pending':
    case 'scheduled':
    case 'partially_paid':
    case 'still_facing':
    case 'rescheduled':
    case 'expiring':
    case 'error':
      return StatusPalette.warning(cs);
    case 'cancelled':
    case 'canceled':
    case 'failed':
    case 'refunded':
    case 'expired':
    case 'deleted':
      return StatusPalette.danger(cs);
    case 'in_progress':
    case 'new':
      return StatusPalette.info(cs);
    default:
      return cs.outline;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.color, this.compact = false, this.dot = false});

  final String status;
  final Color? color;
  final bool compact;

  /// Dense-list variant: a leading status dot instead of a bordered pill.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    if (status.trim().isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final label = Fmt.statusLabel(status);
    final c = color ?? statusColorOf(context, status);

    if (dot) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    final StatusTint tint =
        color != null ? StatusTint(bg: c.withValues(alpha: 0.12), ink: c) : StatusPalette.tintOf(cs, status);

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          color: tint.ink,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}

/// Pull-to-refresh + paginated list scaffold used by list screens.
class PaginatedList<T> extends StatelessWidget {
  const PaginatedList({
    super.key,
    required this.items,
    required this.tile,
    this.meta,
    this.onLoadMore,
    this.loadingMore = false,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.emptyIcon,
  });

  final List<T> items;
  final Widget Function(BuildContext, T, int) tile;
  final ListMeta? meta;
  final Future<void> Function()? onLoadMore;
  final bool loadingMore;
  final String? emptyTitle;
  final String? emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final IconData? emptyIcon;

  bool get _hasMore => (meta != null && meta!.currentPage < meta!.lastPage);

  /// True when the API silently downgraded a requested team_data view to
  /// my_data (carried on [ListMeta.warning]).
  bool get _teamDowngraded => meta?.warning?.trim().isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        title: emptyTitle ?? 'Nothing here yet',
        subtitle: emptySubtitle,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
        icon: emptyIcon,
      );
    }

    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: items.length + (_hasMore ? 1 : 0) + (_teamDowngraded ? 1 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        if (_teamDowngraded && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(
                    alpha: cs.brightness == Brightness.dark ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Team data not available — showing your data',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final bodyIndex = _teamDowngraded ? index - 1 : index;
        if (bodyIndex < items.length) {
          return tile(context, items[bodyIndex], bodyIndex);
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: loadingMore
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: TextButton(
                    onPressed: onLoadMore,
                    child: const Text('Load more'),
                  ),
                ),
        );
      },
    );
  }
}

/// A horizontal filter chip row.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// `(code, label)` pairs; `code == ''` means "All".
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: options.map((entry) {
          final (code, label) = entry;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: code == selected,
              onSelected: (val) {
                // Tapping the selected chip (a real one) returns to "All".
                onSelected(code == selected && code.isNotEmpty ? '' : code);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Consistent "label + value" row for detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.tabular = false});

  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.body.copyWith(
                color: cs.onSurface,
                fontWeight: tabular ? FontWeight.w600 : null,
                fontFeatures: tabular ? AppTypography.tabularFigures : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "My Data / Team Data" segment control used across screens.
class DataScopeSegmentControl extends StatelessWidget {
  const DataScopeSegmentControl({
    super.key,
    required this.selectedView,
    required this.onChanged,
  });

  final String selectedView; // 'my_data' | 'team_data'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(
          color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            for (final (view, label) in [('my_data', 'My data'), ('team_data', 'Team data')])
              Expanded(
                child: _SegmentPill(
                  label: label,
                  active: view == selectedView,
                  isDark: isDark,
                  onTap: view == selectedView ? null : () => onChanged(view),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: active ? (isDark ? const Color(0xFF383838) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active && !isDark
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active
                  ? (isDark ? Colors.white : AppColors.brand)
                  : (isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary button matching the LeadX design system (neutral-900 in light,
/// off-white in dark).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.loading = false,
    this.height = 48,
    this.radius = AppColors.radiusMd,
    this.expand = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool loading;
  final double height;
  final double radius;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btn = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.brandDark : AppColors.brand,
          foregroundColor: isDark ? AppColors.brand : Colors.white,
          disabledBackgroundColor: isDark ? const Color(0xFF525252) : const Color(0xFF737373),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.brand : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Outlined secondary button, or destructive text.
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.loading = false,
    this.height = 48,
    this.radius = AppColors.radiusMd,
    this.expand = true,
    this.destructive = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool loading;
  final double height;
  final double radius;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fg = destructive
        ? (isDark ? AppColors.dangerDark : AppColors.dangerLight)
        : (isDark ? Colors.white : AppColors.brand);
    final border = destructive
        ? (isDark
            ? AppColors.dangerDark.withValues(alpha: 0.5)
            : AppColors.dangerLight.withValues(alpha: 0.5))
        : (isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5));

    final btn = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// A quiet, bordered status badge with an optional leading dot.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.type,
    this.hasDot = true,
    this.compact = false,
    this.ellipsize = false,
  });

  final String status;
  final String? label;
  final String? type;
  final bool hasDot;
  final bool compact;

  /// When true the label ellipsizes to its parent's width instead of forcing
  /// the row to grow — safe inside [Flexible] on narrow screens.
  final bool ellipsize;

  static String resolveType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'active':
      case 'verified':
      case 'success':
      case 'completed':
      case 'paid':
      case 'confirmed':
      case 'uploaded':
      case 'fixed':
      case 'synced':
        return 'success';
      case 'pending':
      case 'scheduled':
      case 'requested':
      case 'partially_paid':
      case 'unverified':
      case 'expiring':
      case 'warning':
        return 'warning';
      case 'failed':
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'expired':
      case 'error':
      case 'overdue':
      case 'still_facing':
      case 'danger':
        return 'danger';
      case 'in_progress':
      case 'rescheduled':
      case 'info':
        return 'info';
      case 'purple':
        return 'purple';
      case 'skipped':
      case 'disabled':
      case 'draft':
      case 'inactive':
      case 'neutral':
      default:
        return 'neutral';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status.trim().isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolved = type ?? resolveType(status);

    Color bg;
    Color ink;
    Color border;

    switch (resolved) {
      case 'success':
        bg = isDark ? const Color(0x2815803D) : const Color(0xFFF0FDF4);
        ink = isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534);
        border = isDark ? const Color(0x4015803D) : const Color(0xFFBBF7D0);
        break;
      case 'warning':
        bg = isDark ? const Color(0x28D97706) : const Color(0xFFFFFBEB);
        ink = isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
        border = isDark ? const Color(0x40D97706) : const Color(0xFFFDE68A);
        break;
      case 'danger':
        bg = isDark ? const Color(0x28DC2626) : const Color(0xFFFEF2F2);
        ink = isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B);
        border = isDark ? const Color(0x40DC2626) : const Color(0xFFFECACA);
        break;
      case 'info':
        bg = isDark ? const Color(0x282563EB) : const Color(0xFFEFF6FF);
        ink = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
        border = isDark ? const Color(0x402563EB) : const Color(0xFFBFDBFE);
        break;
      case 'purple':
        bg = isDark ? const Color(0x287C3AED) : const Color(0xFFFAF5FF);
        ink = isDark ? const Color(0xFFC084FC) : const Color(0xFF6B21A8);
        border = isDark ? const Color(0x407C3AED) : const Color(0xFFE9D5FF);
        break;
      case 'neutral':
      default:
        bg = isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
        ink = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF404040);
        border = isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5);
        break;
    }

    final displayLabel = label ??
        status
            .replaceAll(RegExp(r'[-_]'), ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (ellipsize)
            Flexible(
              child: Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1.2,
                ),
              ),
            )
          else
            Text(
              displayLabel,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: ink,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

/// The sticky app header: flat, quiet chrome.
///
/// Layout: menu + wordmark + role chip on the left, a real [PopupMenuButton]
/// (refresh, notifications, sign out) on the right. The menu actually opens
/// — no more dead hamburger.
class LeadxNavHeader extends StatelessWidget implements PreferredSizeWidget {
  const LeadxNavHeader({
    super.key,
    required this.employeeName,
    this.teamCode,
    this.unreadCount = 0,
    this.onMenuTap,
    this.onRefresh,
    this.onNotifications,
    this.onLogout,
  });

  final String employeeName;
  final String? teamCode;
  final int unreadCount;

  /// Opens the navigation drawer (set when the header sits inside a shell
  /// that owns one; null on the login screen where there is no drawer).
  final VoidCallback? onMenuTap;
  final VoidCallback? onRefresh;
  final VoidCallback? onNotifications;
  final VoidCallback? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF171717);
    final hairline = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5);
    // The static role chips only fit on wide screens; the team chip is the
    // flex part of the row so on narrow screens it squeezes and ellipsizes
    // instead of pushing the actions off the edge.
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        border: Border(
          bottom: BorderSide(color: hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            Material(
              type: MaterialType.transparency,
              child: Tooltip(
                message: 'Menu',
                child: InkWell(
                  onTap: onMenuTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.menu_rounded,
                      size: 20,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Brand: live server site logo (fetching dynamically from server)
          Builder(
            builder: (context) {
              final config = context.watch<AppConfigService>();
              final siteLogoUrl = config.siteLogoUrl;

              Widget fallbackWidget = Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'L',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF171717) : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              );

              Widget logoWidget;
              if (siteLogoUrl != null && siteLogoUrl.isNotEmpty) {
                logoWidget = Image.network(
                  siteLogoUrl,
                  height: 28,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/images/leadx_logo.png',
                    height: 28,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => fallbackWidget,
                  ),
                );
              } else {
                logoWidget = Image.asset(
                  'assets/images/leadx_logo.png',
                  height: 28,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => fallbackWidget,
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 28, maxWidth: 140),
                child: logoWidget,
              );
            },
          ),
          if (wide) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 16, color: hairline),
            const SizedBox(width: 8),
            _RoleChip(label: 'Employee', isDark: isDark),
          ],
          const Spacer(),
          _HeaderAction(
            isDark: isDark,
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
            badge: unreadCount > 0 ? (unreadCount > 99 ? '99+' : '$unreadCount') : null,
          ),
          const SizedBox(width: 8),
          // The menu: a real PopupMenuButton that actually opens.
          PopupMenuButton<String>(
            tooltip: 'Menu',
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252),
            ),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: _MenuItem(icon: Icons.refresh, label: 'Refresh'),
              ),
              if (onNotifications != null)
                const PopupMenuItem(
                  value: 'notifications',
                  child: _MenuItem(icon: Icons.notifications, label: 'Notifications'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: _MenuItem(icon: Icons.logout, label: 'Sign out', destructive: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'refresh':
        onRefresh?.call();
      case 'notifications':
        onNotifications?.call();
      case 'logout':
        onLogout?.call();
    }
  }
}


class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF404040),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.isDark,
    required this.icon,
    this.onTap,
    this.badge,
  });

  final bool isDark;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 19,
                  color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252)),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge!.length > 2 ? '99+' : badge!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? StatusPalette.danger(cs) : cs.onSurface;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A bordered metric card: title, one big figure, optional badge/icon and a
/// quiet caption. [featured] swaps to the dark elevated surface.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.badge,
    this.badgeType = 'neutral',
    this.icon,
    this.accent,
    this.featured = false,
    this.uppercase = false,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final String? badge;
  final String badgeType;
  final IconData? icon;
  final Color? accent;
  final bool featured;
  final bool uppercase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bgColor = featured
        ? (isDark ? const Color(0xFF111111) : const Color(0xFF171717))
        : (isDark ? const Color(0xFF242424) : Colors.white);
    final borderColor = featured
        ? const Color(0xFF171717)
        : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5));

    final titleColor = featured
        ? Colors.white.withValues(alpha: 0.75)
        : (isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373));
    final valueColor = featured
        ? Colors.white
        : (isDark ? const Color(0xFFFAFAFA) : const Color(0xFF171717));
    final subtitleColor = featured
        ? Colors.white.withValues(alpha: 0.6)
        : (isDark ? const Color(0xFF888888) : const Color(0xFFA3A3A3));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: featured
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (accent != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3,
                  child: Container(color: accent),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            uppercase ? title.toUpperCase() : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (featured)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF22C55E),
                            ),
                          )
                        else if (badge != null)
                          StatusBadge(status: badge!, type: badgeType)
                        else if (icon != null)
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFF5F5F5),
                              borderRadius:
                                  BorderRadius.circular(AppColors.radiusSm),
                            ),
                            child: Icon(icon, size: 14, color: titleColor),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: valueColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

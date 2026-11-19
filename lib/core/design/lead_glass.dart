import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_kit/flutter_liquid_glass_kit.dart';
import 'package:provider/provider.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'theme_controller.dart';

/// LeadX's Liquid Glass layer, built on `flutter_liquid_glass_kit`.
///
/// Every chrome/surface decision in the app routes through this class so the
/// kit stays the single glass engine:
///
///  * [LeadGlass.enabled] — the persisted "Liquid Glass" toggle.
///  * [LeadGlass.defaultSettings] / [LeadGlass.settingsFor] — theme-aware
///    kit settings (adaptive matte glass by default; optional colour tints).
///  * [LeadGlass.page] — the per-page [LiquidGlassBackdropGroup]: one native
///    glass host on Apple platforms, and Android blur/shadow throttling
///    while scrolling.
///  * [LeadGlass.card] / [LeadGlass.button] / [LeadGlass.field] — kit
///    surfaces with solid theme fallbacks for the toggle's off state.
///
/// Content data cards (list rows, dashboards) render through
/// `AppCard.surface`, which is kit-glass-aware; use the helpers above for
/// anything AppCard doesn't cover.
class LeadGlass {
  LeadGlass._();

  /// Liquid Glass chrome is retired app-wide: every [LeadGlass] helper
  /// resolves its solid SaaS fallback (white cards, black primary, subtle
  /// shadow), so this always returns [false]. The persisted
  /// [ThemeController.glassEnabled] preference is no longer consulted —
  /// [_lookupTheme] keeps the nullable provider read reachable so a future
  /// back-out only has to restore one return value to
  /// [ThemeController.glassEnabled].
  static bool enabled(BuildContext context) {
    // ignore: unused_local_variable
    final theme = _lookupTheme(context);
    return false;
  }

  /// The persisted "Liquid Glass" preference, kept reachable (but unused) so
  /// a future back-out can resume driving the chrome off `theme.glassEnabled`.
  /// Reads through `Provider.of<ThemeController?>` (nullable-lookup idiom) so
  /// a screen pumped without a [ThemeController] returns null instead of
  /// throwing a ProviderNotFound during build.
  static ThemeController? _lookupTheme(BuildContext context) {
    try {
      return Provider.of<ThemeController?>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// App-wide baseline: adaptive matte glass (tint stays null so the
  /// fallback renderer follows the light/dark theme automatically).
  static const LiquidGlassSettings defaultSettings = LiquidGlassSettings(
    tintOpacity: 0.16,
    blurSigma: 24,
    androidBlurSigma: 8,
    borderOpacity: 0.28,
    shadowOpacity: 0.10,
    shadowBlurRadius: 14,
    shadowOffset: Offset(0, 3),
  );

  /// Theme-aware settings. Pass [tint] for a coloured surface (saturated
  /// tints read best between 0.20 and 0.40 opacity).
  static LiquidGlassSettings settingsFor(BuildContext context,
          {Color? tint, double? tintOpacity}) =>
      defaultSettings.copyWith(
        tintColor: tint,
        tintOpacity: tintOpacity ?? defaultSettings.tintOpacity,
      );

  /// A saturated primary-colour surface for calls to action. Dark mode
  /// tints with the indigo secondary accent ([AppColors.emeraldAccent]
  /// retargeted to indigo-600 — a near-white wash would read as a
  /// highlight, not a CTA surface); light mode uses the near-black brand.
  static LiquidGlassSettings primarySettings(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return defaultSettings.copyWith(
      tintColor: isDark ? AppColors.emeraldAccent : cs.primary,
      tintOpacity: isDark ? 0.35 : 0.32,
    );
  }

  /// Wraps one page's content so its glass surfaces share a backdrop group
  /// (and get scroll performance throttling on Android).
  static Widget page(BuildContext context, Widget child,
      {LiquidGlassSettings settings = defaultSettings}) {
    return enabled(context)
        ? LiquidGlassBackdropGroup(settings: settings, child: child)
        : child;
  }

  /// A glass card. When the glass toggle is off, a solid theme surface with
  /// the same geometry is drawn instead.
  static Widget card(
    BuildContext context,
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double radius = AppColors.radiusLg,
    Color? tint,
    double? tintOpacity,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (!enabled(context)) {
      return Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(radius),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
          boxShadow: [
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }
    return LiquidGlassCard(
      settings: settingsFor(context, tint: tint, tintOpacity: tintOpacity),
      borderRadius: BorderRadius.circular(radius),
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      child: onTap == null
          ? child
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: child,
              ),
            ),
    );
  }

  /// A glass action button. [primary] tints the surface with the app's
  /// brand colour; otherwise it is matte adaptive glass.
  static Widget button(
    BuildContext context,
    Widget child, {
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool primary = false,
    double radius = AppColors.radiusLg,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  }) {
    final cs = Theme.of(context).colorScheme;
    if (!enabled(context)) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          backgroundColor: primary ? cs.primary : null,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : child,
      );
    }
    return LiquidGlassButton(
      settings: primary ? primarySettings(context) : settingsFor(context),
      borderRadius: BorderRadius.circular(radius),
      padding: padding,
      onPressed: onPressed,
      isLoading: isLoading,
      child: child,
    );
  }

  /// A Liquid Glass filter/segment bar (the kit's cousin of the old
  /// `GlassSegmentBar`): a matte glass capsule with a springy selection
  /// highlight. Renders as a plain solid pill bar when glass is off.
  static Widget segmentBar(
    BuildContext context,
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected, {
    double height = 38,
  }) {
    final cs = Theme.of(context).colorScheme;
    final glassOn = enabled(context);
    final active = cs.brightness == Brightness.dark ? AppColors.brandDark : cs.primary;

    if (!glassOn) {
      return _SolidSegmentBar(
        labels: labels,
        selected: selected,
        onSelected: onSelected,
        height: height,
      );
    }

    const capsule = LiquidGlassSettings(
      tintColor: Colors.white,
      tintOpacity: 0.18,
      blurSigma: 16,
      androidBlurSigma: 6,
      borderOpacity: 0.25,
      shadowOpacity: 0.08,
      shadowBlurRadius: 10,
      shadowOffset: Offset(0, 2),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The card's 3px inner padding shrinks the content area.
        const cardPadding = 6.0;
        final contentWidth = (constraints.maxWidth - cardPadding).clamp(0.0, double.infinity);
        return LiquidGlassCard(
          settings: capsule,
          borderRadius: BorderRadius.circular(height / 2),
          padding: const EdgeInsets.all(3),
          height: height,
          child: _SlidingIndicator(
            labels: labels,
            selected: selected,
            onSelected: onSelected,
            active: active,
            width: contentWidth,
          ),
        );
      },
    );
  }

  /// Paints a form control (text field, dropdown, …) on a glass surface.
  ///
  /// The control should use [fieldDecoration] so it does not draw its own
  /// solid fill or border — the glass surface provides the outline.
  static Widget field(
    BuildContext context,
    Widget child, {
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    double radius = AppColors.radiusLg,
    Color? tint,
    double? width,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (!enabled(context)) {
      return Container(
        width: width,
        margin: margin,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(padding: contentPadding, child: child),
      );
    }
    return LiquidGlassCard(
      settings: settingsFor(context, tint: tint),
      borderRadius: BorderRadius.circular(radius),
      padding: contentPadding,
      margin: margin,
      width: width,
      child: child,
    );
  }

  /// An [InputDecoration] that belongs on a glass surface: no solid fill,
  /// no static border — only a quiet primary-colour focus outline.
  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    Widget? prefix,
  }) {
    final cs = Theme.of(context).colorScheme;
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.7), width: 1.2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: cs.onSurfaceVariant),
      suffixIcon: suffixIcon,
      prefix: prefix,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      focusedBorder: focusBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
      labelStyle: AppTypography.body.copyWith(color: cs.onSurfaceVariant),
      hintStyle: AppTypography.body.copyWith(
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }

  /// The bottom tab bar for the authenticated shell: the kit's
  /// [LiquidGlassNavBar] (native `UITabBar` on iOS 26+, the animated glass
  /// dock on Android). When the glass gate is off (today, always), a solid
  /// Material [NavigationBar] with the same four destinations and the same
  /// selection callback is drawn instead: neutral surface, soft neutral
  /// indicator, black (light) / near-white (dark) selected icon.
  static Widget navBar(
    BuildContext context,
    int currentIndex,
    ValueChanged<int> onSelected,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (!enabled(context)) {
      // Solid fallback: same items (Home/Orders/Tasks/People) and callback
      // API as the kit dock, 44px+ touch targets, neutral palette only.
      final iconColor = cs.onSurface.withValues(alpha: 0.55);
      final selectedIconColor =
          cs.brightness == Brightness.dark ? AppColors.brandDark : AppColors.brand;
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        height: 80,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: iconColor),
            selectedIcon:
                Icon(Icons.dashboard, color: selectedIconColor),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined, color: iconColor),
            selectedIcon: Icon(Icons.shopping_bag, color: selectedIconColor),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined, color: iconColor),
            selectedIcon: Icon(Icons.task_alt, color: selectedIconColor),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined, color: iconColor),
            selectedIcon: Icon(Icons.people, color: selectedIconColor),
            label: 'People',
          ),
        ],
      );
    }
    final accent = cs.brightness == Brightness.dark
        ? AppColors.brandDark
        : cs.primary;
    return LiquidGlassNavBar(
      settings: settingsFor(context,
          tint: Colors.black,
          tintOpacity:
              cs.brightness == Brightness.dark ? 0.45 : 0.28),
      items: [
        LiquidGlassNavItem(
          icon: const Icon(Icons.dashboard_outlined),
          activeIcon: const Icon(Icons.dashboard),
          label: 'Home',
          iosSystemImage: 'square.grid.2x2',
          iosSelectedSystemImage: 'square.grid.2x2.fill',
        ),
        LiquidGlassNavItem(
          icon: const Icon(Icons.shopping_bag_outlined),
          activeIcon: const Icon(Icons.shopping_bag),
          label: 'Orders',
          iosSystemImage: 'cart',
          iosSelectedSystemImage: 'cart.fill',
        ),
        LiquidGlassNavItem(
          icon: const Icon(Icons.task_alt_outlined),
          activeIcon: const Icon(Icons.task_alt),
          label: 'Tasks',
          iosSystemImage: 'checklist',
          iosSelectedSystemImage: 'checklist.checked',
        ),
        LiquidGlassNavItem(
          icon: const Icon(Icons.people_outlined),
          activeIcon: const Icon(Icons.people),
          label: 'People',
          iosSystemImage: 'person.2',
          iosSelectedSystemImage: 'person.2.fill',
        ),
      ],
      currentIndex: currentIndex,
      onTap: onSelected,
      activeColor: accent,
      inactiveColor: Colors.white.withValues(alpha: 0.65),
    );
  }

}

/// A Liquid Glass search capsule (the kit's cousin of Veneer's
/// `NativeSearchField`): magnifier + hint on a matte glass pill. The
/// controller lives in the widget's state, so the query survives parent
/// rebuilds. Renders a solid theme capsule when glass is off.
class LeadGlassSearchField extends StatefulWidget {
  const LeadGlassSearchField({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.height = 44,
  });

  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final double height;

  @override
  State<LeadGlassSearchField> createState() => _LeadGlassSearchFieldState();
}

class _LeadGlassSearchFieldState extends State<LeadGlassSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = widget.height;
    final glassOn = LeadGlass.enabled(context);

    final field = TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: AppTypography.body.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
        contentPadding: EdgeInsets.zero,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(h / 2),
          borderSide: BorderSide(
              color: cs.primary.withValues(alpha: 0.6), width: 1.2),
        ),
        hintStyle: AppTypography.body.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );

    if (!glassOn) {
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(h / 2),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child:
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: field),
      );
    }

    return LiquidGlassCard(
      settings: LeadGlass.settingsFor(context),
      borderRadius: BorderRadius.circular(h / 2),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: h,
      child: field,
    );
  }
}

// ── Private segment-bar pieces ───────────────────────────────────────

/// The solid (glass-off) segment bar: a plain pill track with a filled
/// selection, matching the layout of the kit glass bar.
class _SolidSegmentBar extends StatelessWidget {
  const _SolidSegmentBar({
    required this.labels,
    required this.selected,
    required this.onSelected,
    required this.height,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = cs.brightness == Brightness.dark ? AppColors.brandDark : cs.primary;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    decoration: BoxDecoration(
                      color: i == selected ? active : Colors.transparent,
                      borderRadius: BorderRadius.circular(height / 2 - 6),
                    ),
                    child: Text(
                      labels[i],
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                        color: i == selected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The selection layer inside the glass capsule: an animated highlight
/// that slides to the selected segment, plus the tappable labels.
class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator({
    required this.labels,
    required this.selected,
    required this.onSelected,
    required this.active,
    required this.width,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color active;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = labels.length;
    if (n == 0) return const SizedBox.shrink();
    final slot = width / n;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Sliding highlight.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          left: selected * slot + 2,
          width: slot - 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight:
                            i == selected ? FontWeight.w700 : FontWeight.w500,
                        color: i == selected
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

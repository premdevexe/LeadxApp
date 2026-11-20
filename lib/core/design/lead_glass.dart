import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// LeadX's solid surface layer.
///
/// The liquid-glass engine was retired app-wide; this class is the
/// solid-only implementation: every helper resolves the flat SaaS chrome
/// (white / near-black surfaces, hairline borders, subtle shadow) with no
/// glass dependencies. Kept as the single call site so the screens stay
/// written against one surface API.
class LeadGlass {
  LeadGlass._();

  /// Always false — the glass gate is gone, not just off.
  static bool enabled(BuildContext context) => false;

  /// A solid card: white (light) or near-black (dark) surface with a 1px
  /// hairline and a subtle shadow.
  static Widget card(
    BuildContext context,
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double radius = AppColors.radiusLg,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
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

  /// A solid action button: [primary] tints the surface with the app's
  /// brand colour; otherwise it is a neutral filled button.
  static Widget button(
    BuildContext context,
    Widget child, {
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool primary = false,
    double radius = AppColors.radiusLg,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  }) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        backgroundColor: primary ? cs.primary : null,
        padding: padding,
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

  /// A solid filter/segment bar: a sleek segmented track with a filled
  /// selection indicator that smoothly spans the entire active slot.
  static Widget segmentBar(
    BuildContext context,
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected, {
    double height = 40,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final activeBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final activeFg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inactiveFg =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final trackBg =
        isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9);
    final borderColor =
        isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0);

    return Container(
      height: height,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: i == selected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: (i == selected && !isDark)
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12.5,
                      fontWeight:
                          i == selected ? FontWeight.w600 : FontWeight.w500,
                      color: i == selected ? activeFg : inactiveFg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A solid form surface: [child] on a bordered card.
  static Widget field(
    BuildContext context,
    Widget child, {
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    double radius = AppColors.radiusLg,
    double? width,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    final cs = Theme.of(context).colorScheme;
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

  /// An [InputDecoration] that sits inside [field]: no solid fill, no static
  /// border — only a quiet focus outline.
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
      borderSide: BorderSide(
          color: cs.primary.withValues(alpha: 0.7), width: 1.2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      borderSide: BorderSide(color: cs.error, width: 1.2),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          prefixIcon == null ? null : Icon(prefixIcon, color: cs.onSurfaceVariant),
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

  /// The solid bottom tab bar with the four app destinations
  /// (Home / Orders / Tasks / People).
  static Widget navBar(
    BuildContext context,
    int currentIndex,
    ValueChanged<int> onSelected,
  ) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = cs.onSurface.withValues(alpha: 0.55);
    final selectedIconColor = cs.brightness == Brightness.dark
        ? AppColors.brandDark
        : AppColors.brand;
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
          selectedIcon: Icon(Icons.dashboard, color: selectedIconColor),
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
}

/// A solid search capsule: magnifier + hint on a bordered pill. The
/// controller lives in the widget's state so the query survives parent
/// rebuilds.
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
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = widget.height;

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(h / 2),
        border: Border.all(
          color: _isFocused
              ? cs.primary.withValues(alpha: 0.8)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: _isFocused ? 1.4 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: _isFocused ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (val) {
                widget.onChanged(val);
                setState(() {});
              },
              onSubmitted: widget.onSubmitted,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              style: AppTypography.body.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: AppTypography.body.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                errorText: null,
                errorStyle: const TextStyle(fontSize: 0, height: 0),
                helperText: null,
                helperStyle: const TextStyle(fontSize: 0, height: 0),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onChanged('');
                setState(() {});
              },
              child: Icon(
                Icons.cancel,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

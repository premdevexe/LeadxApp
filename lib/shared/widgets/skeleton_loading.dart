import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';

/// A lightweight, GPU-accelerated pulsing shimmer effect for native skeleton screens.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A generic skeleton block with customizable dimensions and corner radius.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.circular(AppColors.radiusSm)),
      ),
    );
  }
}

/// A skeleton placeholder for dashboard summary cards.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 100});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final border = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE5E7EB);

    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox(width: 80, height: 12),
              SkeletonBox(width: 16, height: 16, shape: BoxShape.circle),
            ],
          ),
          const SkeletonBox(width: 110, height: 22),
          const SkeletonBox(width: 60, height: 10),
        ],
      ),
    );
  }
}

/// A skeleton list placeholder that matches standard LeadX list tiles (Orders, Customers, Payments).
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({
    super.key,
    this.itemCount = 6,
    this.cardHeight,
    this.padding,
  });

  final int itemCount;
  final double? cardHeight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final border = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE5E7EB);

    return SkeletonShimmer(
      child: ListView.separated(
        padding: padding ?? const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) {
          return Container(
            height: cardHeight,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 140, height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 11),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    SkeletonBox(width: 65, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 45, height: 11),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

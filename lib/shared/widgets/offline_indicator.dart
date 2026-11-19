import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_typography.dart';
import '../../core/services/connectivity_service.dart';

/// A subtle, non-intrusive floating indicator that animates in whenever
/// device network connection is dropped.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final isOffline = connectivity.isOffline;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 6,
          left: 16,
          right: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            reverseDuration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: isOffline
                ? Material(
                    key: const ValueKey('offline_pill'),
                    color: Colors.transparent,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Offline mode • Cached data shown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('online_empty')),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/app_services.dart';
import '../../core/services/biometric_service.dart';
import '../../core/utils/native_feedback.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../customer_issues/customer_issues_screen.dart';
import '../customers/customers_screen.dart';
import '../follow_ups/follow_ups_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../orders/order_create_sheet.dart';
import '../performance/performance_screen.dart';
import '../payments/payments_screen.dart';
import '../profile/profile_screen.dart';
import '../subscriptions/expiring_subscriptions_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import 'dashboard_screen.dart';

/// The **solid** authenticated shell — the Material fallback used when the
/// user switches off the liquid-glass navigation in Profile → Preferences.
/// Same 13 panels, same data; just plain, high-contrast chrome instead of
/// refractive glass.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  DateTime? _lastBackTime;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _pausedAt;
  String? _lockError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (BiometricService.shared.isBiometricEnabled) {
      _isLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometricAuth();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Record pause timestamp only when not actively showing a biometric prompt
      if (!BiometricService.shared.isAuthenticating && !_isAuthenticating) {
        _pausedAt = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      final bio = BiometricService.shared;
      // If already locked or actively authenticating, skip
      if (_isLocked || _isAuthenticating || bio.isAuthenticating) {
        return;
      }

      // Ignore resume events if authentication just succeeded in the last 2.5 seconds
      final lastSuccess = bio.lastAuthSuccessTime;
      if (lastSuccess != null &&
          DateTime.now().difference(lastSuccess) < const Duration(milliseconds: 2500)) {
        return;
      }

      // Only lock if the app was genuinely backgrounded by user action
      final wasBackgrounded = _pausedAt != null &&
          DateTime.now().difference(_pausedAt!) > const Duration(milliseconds: 500);
      _pausedAt = null;

      if (bio.isBiometricEnabled && bio.lockOnResume && wasBackgrounded) {
        setState(() {
          _isLocked = true;
          _lockError = null;
        });
        _triggerBiometricAuth();
      }
    }
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _lockError = null;
    });

    final result = await BiometricService.shared.authenticateDetailed(
      reason: 'Authenticate to unlock LeadX CRM',
    );

    if (!mounted) return;
    setState(() {
      _isAuthenticating = false;
      if (result.success) {
        _isLocked = false;
        _lockError = null;
      } else {
        _lockError = result.errorMessage;
      }
    });

    if (result.success) {
      NativeFeedback.light();
    } else {
      NativeFeedback.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final screens = <Widget>[
      const DashboardScreen(),
      const OrdersScreen(),
      const FollowUpsScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    final employeeName = auth.me?.data.name ?? 'Employee';
    final teamName = auth.me?.data.team?.teamName;
    final email = auth.me?.data.email ?? auth.me?.data.username ?? '';

    final cs = Theme.of(context).colorScheme;
    final menu = Drawer(
      child: _MenuBody(
        employeeName: employeeName,
        email: email,
        teamName: teamName,
        canCreateOrders: auth.canCreateOrders,
        hasTeamDataAccess: auth.hasTeamDataAccess,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If app is currently locked by biometrics, allow immediate exit
        if (_isLocked) {
          SystemNavigator.pop();
          return;
        }

        // If not on the primary dashboard tab, navigate back to dashboard
        if (_index != 0) {
          NativeFeedback.selection();
          setState(() => _index = 0);
          return;
        }

        // On dashboard tab: require double back press within 2 seconds to exit app
        final now = DateTime.now();
        if (_lastBackTime == null || now.difference(_lastBackTime!) > const Duration(seconds: 2)) {
          _lastBackTime = now;
          NativeFeedback.light();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit LeadX'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // Allow app exit on second back press
        SystemNavigator.pop();
      },
      child: Stack(
        children: [
          Scaffold(
            drawer: menu,
            endDrawer: menu,
            body: AnimatedIndexedStack(index: _index, children: screens),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                ),
                child: NavigationBar(
                  height: 62,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF1F5F9),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _index,
                  onDestinationSelected: (i) {
                    if (i != _index) {
                      NativeFeedback.selection();
                      setState(() => _index = i);
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined, size: 20),
                      selectedIcon: Icon(Icons.dashboard_rounded, size: 20),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined, size: 20),
                      selectedIcon: Icon(Icons.receipt_long_rounded, size: 20),
                      label: 'Orders',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.task_alt_outlined, size: 20),
                      selectedIcon: Icon(Icons.task_alt_rounded, size: 20),
                      label: 'Follow-ups',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_none_rounded, size: 20),
                      selectedIcon: Icon(Icons.notifications_rounded, size: 20),
                      label: 'Notifications',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded, size: 20),
                      selectedIcon: Icon(Icons.person_rounded, size: 20),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLocked)
            _buildLockOverlay(
              isDark: Theme.of(context).brightness == Brightness.dark,
              employeeName: employeeName,
            ),
        ],
      ),
    );
  }

  Widget _buildLockOverlay({
    required bool isDark,
    required String employeeName,
  }) {
    final pageBg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: pageBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Lock Icon Tile
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: cardBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_rounded,
                    size: 42,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'LeadX is Locked',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Welcome back, $employeeName\nAuthenticate to unlock your CRM session',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: textSecondary,
                ),
              ),

              const Spacer(flex: 2),

              if (_lockError != null && _lockError!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3F1B1B) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lockError!,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Unlock Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _triggerBiometricAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isAuthenticating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded, size: 22),
                  label: Text(
                    _isAuthenticating ? 'Authenticating…' : 'Unlock with Biometrics',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Sign Out Option
              TextButton(
                onPressed: () {
                  context.read<AuthController>().logout();
                },
                child: Text(
                  'Sign out of account',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({
    required this.employeeName,
    required this.email,
    this.teamName,
    required this.canCreateOrders,
    required this.hasTeamDataAccess,
  });

  final String employeeName;
  final String email;
  final String? teamName;
  final bool canCreateOrders;
  final bool hasTeamDataAccess;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.read<AuthController>();
    final cs = Theme.of(context).colorScheme;

    void close() => Navigator.of(context).pop();

    Widget row(IconData icon, String label, VoidCallback? onTap,
        {Color? labelColor}) {
      final color = labelColor;
      return ListTile(
        leading: Icon(icon, color: color ?? cs.onSurfaceVariant),
        title: Text(
          label,
          style: AppTypography.cardTitle.copyWith(
            color: color ?? cs.onSurface,
            fontSize: 14,
            fontWeight: color != null ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap ?? close,
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            text.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        );

    Future<void> logout() async {
      close();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign out'),
          content: const Text('End your current session on this device?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: StatusPalette.danger(cs),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirm == true) auth.logout();
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Sidebar header matching sidebar-header in employee.blade.php
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) {
                    final config = context.watch<AppConfigService>();
                    final siteLogoUrl = config.siteLogoUrl;

                    Widget fallback = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF171717),
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
                          child: Center(
                            child: Text(
                              config.siteName.isNotEmpty ? config.siteName[0].toUpperCase() : 'L',
                              style: TextStyle(
                                color: cs.brightness == Brightness.dark
                                    ? const Color(0xFF171717)
                                    : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          config.siteName,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    );

                    Widget logoWidget;
                    if (siteLogoUrl != null && siteLogoUrl.isNotEmpty) {
                      logoWidget = Image.network(
                        siteLogoUrl,
                        height: 32,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/leadx_logo.png',
                          height: 32,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                      );
                    } else {
                      logoWidget = Image.asset(
                        'assets/images/leadx_logo.png',
                        height: 32,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) => fallback,
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 32, maxWidth: 160),
                      child: logoWidget,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: close,
                  tooltip: 'Close menu',
                ),
              ],
            ),
          ),
        ),
        // Employee User Card matching sidebar in employee.blade.php
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.brightness == Brightness.dark
                ? const Color(0xFF262626)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: cs.brightness == Brightness.dark
                  ? const Color(0xFF333333)
                  : const Color(0xFFE5E5E5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF171717),
                ),
                child: Center(
                  child: Text(
                    employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'E',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (teamName != null && teamName!.isNotEmpty)
                StatusBadge(
                  status: teamName!,
                  type: 'neutral',
                  hasDot: false,
                  compact: true,
                ),
            ],
          ),
        ),
        header('Overview'),
        row(Icons.notifications_none, 'Notifications',
            () {
              close();
              _nav(context, const NotificationsScreen());
            }),
        header('Sales & CRM'),
        if (canCreateOrders)
          row(Icons.add_circle_outline, 'Create Order',
              () => showOrderCreateSheet(context, services)),
        row(Icons.shopping_bag_outlined, 'Orders', () => _nav(context, const OrdersScreen())),
        row(Icons.payment_outlined, 'Payments', () => _nav(context, const PaymentsScreen())),
        row(Icons.people_outline, 'Customers', () => _nav(context, const CustomersScreen())),
        row(Icons.insights_outlined, 'Performance Report', () => _nav(context, const PerformanceScreen())),
        header('Subscriptions'),
        row(Icons.credit_card_outlined, 'Subscriptions', () => _nav(context, const SubscriptionsScreen())),
        row(Icons.alarm_outlined, 'Expiry Reminders', () => _nav(context, const ExpiringSubscriptionsScreen())),
        header('Activities & Support'),
        row(Icons.task_alt_outlined, 'Follow-ups', () => _nav(context, const FollowUpsScreen())),
        row(Icons.report_problem_outlined, 'Customer Issues', () => _nav(context, const CustomerIssuesScreen())),
        header('Account'),
        row(Icons.logout, 'Logout', logout,
            labelColor: StatusPalette.danger(cs)),
        const SizedBox(height: 16),
      ],
    );
  }

  void _nav(BuildContext context, Widget screen) {
    // The end drawer is closed by the parent; just push the destination.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// A smooth, state-preserving animated indexed stack that applies a fluid
/// fade and subtle glide when switching bottom navigation destinations.
class AnimatedIndexedStack extends StatefulWidget {
  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.012),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _currentIndex = widget.index;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(
          index: _currentIndex,
          children: widget.children,
        ),
      ),
    );
  }
}

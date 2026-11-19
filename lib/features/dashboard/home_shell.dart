import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_screen.dart';
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

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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

    return Scaffold(
      drawer: menu,
      endDrawer: menu,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
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
          onDestinationSelected: (i) => setState(() => _index = i),
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
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      child: const Center(
                        child: Text(
                          'L',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'LeadX',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
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
        row(Icons.calendar_today_outlined, 'Google Calendar', () => _nav(context, const CalendarScreen())),
        row(Icons.report_problem_outlined, 'Customer Issues', () => _nav(context, const CustomerIssuesScreen())),
        header('Account'),
        row(Icons.person_outline, 'Profile & Settings', () => _nav(context, const ProfileScreen())),
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

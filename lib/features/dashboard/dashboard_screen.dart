import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/dashboard.dart' as m;
import '../../shared/models/order.dart' show Order;
import '../../shared/models/subscription.dart' show Subscription;
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../customers/customers_screen.dart';
import '../follow_ups/follow_up_create_sheet.dart';
import '../follow_ups/follow_up_detail_screen.dart';
import '../follow_ups/follow_ups_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/order_create_sheet.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_screen.dart';
import '../payments/payments_screen.dart';
import '../profile/profile_screen.dart';
import '../search/global_search_screen.dart';
import '../subscriptions/expiring_subscriptions_screen.dart';
import '../subscriptions/subscription_detail_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import 'crm_hub_sheet.dart';

/// The employee dashboard: personalized greeting, profile summary, today's
/// statistics, revenue/payment summaries, upcoming follow-ups and recent
/// activity — every figure formatted through the admin currency config.
/// Faithfully mirrors employee-dashboard-preview.html & dashboard.blade.php.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  m.Dashboard? _data;
  bool _loading = true;
  String? _error;
  String _view = 'my_data';

  /// True while the API has denied `view=team_data` (403 or similar) — the
  /// screen then keeps the My Data data with an unobtrusive notice.
  bool _teamDenied = false;

  /// Customization state for the 9 dashboard metric cards
  final Map<String, bool> _cardVisibility = {
    'orders_count': true,
    'sales_value': true,
    'verified_revenue': true,
    'customers_count': true,
    'active_subscriptions': true,
    'pending_payments': true,
    'expiring_subscriptions': true,
    'follow_ups': true,
    'monthly_performance': true,
  };

  static const _availableCards = [
    ('orders_count', 'My Total Orders'),
    ('sales_value', 'My Sales / Closing Value'),
    ('verified_revenue', 'My Verified Revenue'),
    ('customers_count', 'My Customers'),
    ('active_subscriptions', 'My Active Subscriptions'),
    ('pending_payments', 'My Pending Payments'),
    ('expiring_subscriptions', 'My Expiring Subscriptions'),
    ('follow_ups', 'My Follow-ups'),
    ('monthly_performance', 'My Monthly Performance'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the dashboard for [_view]; a rejected team_data view falls back
  /// to the My Data payload so the screen never dead-ends on a 403.
  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _data == null;
      _error = null;
    });

    var view = _view;
    try {
      context.read<AppConfigService>().refresh();
      final res = await services.api.dashboard(view: view);
      final dashboard = m.Dashboard.fromJson(res);
      if (!mounted) return;
      setState(() {
        _data = dashboard;
        _loading = false;
        _teamDenied = false;
      });
      return;
    } on ApiException catch (e) {
      if (view == 'team_data' && (e.isForbidden || e.isNotFound)) {
        view = 'my_data';
      }
      try {
        final res = await services.api.dashboard(view: view);
        final dashboard = m.Dashboard.fromJson(res);
        if (!mounted) return;
        setState(() {
          _data = dashboard;
          _loading = false;
          _error = null;
        });
      } on ApiException catch (e2) {
        if (!mounted) return;
        setState(() {
          _error = e2.isNetwork || e2.isTimeout
              ? 'No connection. Retrying…'
              : e2.message;
          _loading = false;
        });
      }
      if (!mounted) return;
      setState(() {
        _teamDenied = _view == 'team_data' && _error == null && _data != null;
      });
    }
  }

  void _openNavigationMenu(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.hasDrawer == true) {
      scaffold!.openDrawer();
    } else if (scaffold?.hasEndDrawer == true) {
      scaffold!.openEndDrawer();
    } else {
      showCrmHubSheet(context);
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthController auth) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('End your current session on this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StatusPalette.danger(cs),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm == true) auth.logout();
  }

  void _showCustomizeCardsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                side: BorderSide(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
                ),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Customize Dashboard Metric Cards',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF171717),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check cards you want to display on your sales dashboard.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final card in _availableCards)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF383838) : const Color(0xFFF0F0F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        card.$2,
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : const Color(0xFF171717),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: _cardVisibility[card.$1] ?? true,
                                          activeColor: isDark ? AppColors.brandDark : AppColors.brand,
                                          onChanged: (val) {
                                            setModalState(() {
                                              _cardVisibility[card.$1] = val ?? true;
                                            });
                                            setState(() {});
                                          },
                                        ),
                                        Text(
                                          'Show',
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              for (final card in _availableCards) {
                                _cardVisibility[card.$1] = true;
                              }
                            });
                            setState(() {});
                          },
                          child: const Text(
                            'Reset Defaults',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : const Color(0xFF171717),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: isDark ? AppColors.brandDark : AppColors.brand,
                                foregroundColor: isDark ? AppColors.brand : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: const Text('Save Layout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final auth = context.watch<AuthController>();
    final services = context.read<AppServices>();
    final employeeName = auth.me?.data.name ?? 'Employee';
    final username = auth.me?.data.username ?? 'employee';
    final teamName = auth.me?.data.team?.teamName ?? 'Unassigned';
    final teamCode = auth.me?.data.team?.teamCode ?? teamName;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    Widget body;
    if (_loading && _data == null) {
      body = const LoadingScreen();
    } else if (_error != null && _data == null) {
      body = Builder(
        builder: (context) {
          final top = MediaQuery.paddingOf(context).top;
          return Material(
            color: cs.surface,
            child: Stack(
              children: [
                RefreshIndicator(
                  edgeOffset: top + 56,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, top + 56 + 16, 16, 16),
                    children: [ErrorBanner(message: _error!, onRetry: _load)],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: isDark ? const Color(0xFF171717) : Colors.white,
                    padding: EdgeInsets.only(top: top),
                    child: LeadxNavHeader(
                      employeeName: employeeName,
                      teamCode: teamCode,
                      unreadCount: 0,
                      onMenuTap: () => _openNavigationMenu(context),
                      onLogoTap: _load,
                      onNotificationsTap: () => _push(context, const NotificationsScreen()),
                      onProfileTap: () => _push(context, const ProfileScreen()),
                      onLogoutTap: () => _confirmLogout(context, auth),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      final d = _data!;
      final s = d.summary;
      final unreadCount = d.recentNotifications.where((n) => !n.isRead).length;

      body = Builder(
        builder: (context) {
          final top = MediaQuery.paddingOf(context).top;
          return Material(
            color: cs.surface,
            child: Stack(
              children: [
                RefreshIndicator(
                  edgeOffset: top + 56,
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, top + 56 + 12, 16, 120),
                    children: [
                      // ── Top Bar: Greeting + Sales Dashboard Title & Subtitle ─
                      _DashboardTopBar(
                        employeeName: employeeName,
                        username: username,
                        teamName: teamName,
                        view: _view,
                        greeting: greeting,
                      ),
                      const SizedBox(height: 10),

                      // ── Header Controls: Customize Cards & Scope Segment ───
                      Row(
                        children: [
                          InkWell(
                            onTap: _showCustomizeCardsDialog,
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262626) : Colors.white,
                                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF404040) : const Color(0xFFD4D4D4),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 14,
                                    color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Customize Cards',
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF404040),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 190,
                            child: DataScopeSegmentControl(
                              selectedView: _view,
                              onChanged: (next) {
                                if (next == _view) return;
                                setState(() {
                                  _view = next;
                                  _teamDenied = false;
                                });
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Alerts / Notices ──────────────────────────────────────
                      if (_teamDenied) ...[
                        const _ScopeNotice(),
                        const SizedBox(height: 6),
                      ],

                      if (_view == 'team_data') ...[
                        _TeamDataModeAlert(
                          onSwitchToMyData: () {
                            setState(() {
                              _view = 'my_data';
                              _teamDenied = false;
                            });
                            _load();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (d.warning != null) ...[
                        AppCard.surface(
                          context,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: cs.tertiaryContainer,
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: cs.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  d.warning!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.secondary.copyWith(
                                    color: cs.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Primary Stat Cards (§4.1: Collected vs Due) ───────────
                      _CollectedVsDueCard(
                        summary: s,
                        onTap: () => _push(context, const OrdersScreen()),
                      ),
                      const SizedBox(height: 12),

                      // ── 9 Metric Cards Grid ───────────────────────────────────
                      _buildMetricCards(context, s, isDark),
                      const SizedBox(height: 18),

                      // ── Middle Section: My Recent Orders & Portal Actions ─────
                      _buildRecentOrdersAndActions(context, d, auth, services, isDark),
                      const SizedBox(height: 18),

                      // ── Lower Section: Follow-ups & Expiring Reminders ────────
                      _buildFollowUpsAndExpiring(context, d, isDark),
                      const SizedBox(height: 18),

                      // ── Bottom Section: 6-Month Sales Trajectory ──────────────
                      if (d.monthlySalesChart.isNotEmpty) ...[
                        _buildTrajectorySection(context, d.monthlySalesChart, isDark),
                        const SizedBox(height: 18),
                      ],

                      // ── LeadX Employee Portal Footer ──────────────────────────
                      _buildEmployeeFooter(isDark),
                    ],
                  ),
                ),

                // ── Sticky LeadxNavHeader matching <header class="page-header"> ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: isDark ? const Color(0xFF171717) : Colors.white,
                    padding: EdgeInsets.only(top: top),
                    child: LeadxNavHeader(
                      employeeName: employeeName,
                      teamCode: teamCode,
                      unreadCount: unreadCount,
                      onMenuTap: () => _openNavigationMenu(context),
                      onLogoTap: _load,
                      onNotificationsTap: () => _push(context, const NotificationsScreen()),
                      onProfileTap: () => _push(context, const ProfileScreen()),
                      onLogoutTap: () => _confirmLogout(context, auth),
                    ),
                  ),
                ),

                // ── Floating Action Dock (Search & + Order) ───────────────
                Positioned(
                  bottom: 112,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppColors.radiusXl),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DockAction(
                          context,
                          icon: const Icon(Icons.search, size: 20),
                          onTap: () => _push(context, const GlobalSearchScreen()),
                        ),
                        if (auth.canCreateOrders)
                          _DockAction(
                            context,
                            primary: true,
                            icon: const Icon(Icons.add, size: 20),
                            onTap: () => showOrderCreateSheet(context, services),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return NativeNavigationBar(
      title: NativeBarTitle(
        title: 'LeadX Dashboard',
        subtitle: '$greeting, $employeeName',
        capsule: true,
        icon: const NativeIcon.symbol(
          'chart.bar.xaxis',
          fallback: Icons.bar_chart_rounded,
        ),
      ),
      leading: NativeBarButton(
        icon: const NativeIcon.symbol('sparkles', fallback: Icons.auto_awesome),
        title: 'Executive Hub',
        onPressed: () => showCrmHubSheet(context),
      ),
      trailing: [
        if (auth.canCreateOrders)
          NativeBarButton(
            icon: const NativeIcon.symbol('plus', fallback: Icons.add),
            title: 'New',
            prominent: true,
            group: 1,
            menu: [
              NativeMenuItem(
                title: 'New Order',
                icon: const NativeIcon.symbol(
                  'cart.badge.plus',
                  fallback: Icons.add_shopping_cart,
                ),
                onSelected: () => showOrderCreateSheet(context, services),
              ),
              NativeMenuItem(
                title: 'Schedule Follow-up',
                icon: const NativeIcon.symbol(
                  'calendar.badge.plus',
                  fallback: Icons.event,
                ),
                onSelected: () => showFollowUpCreateSheet(context),
              ),
            ],
          ),
        NativeBarButton(
          icon: const NativeIcon.symbol(
            'magnifyingglass',
            fallback: Icons.search,
          ),
          title: 'Search',
          group: 0,
          onPressed: () => _push(context, const GlobalSearchScreen()),
        ),
        NativeBarButton(
          icon: const NativeIcon.symbol(
            'bell',
            fallback: Icons.notifications_none,
          ),
          title: 'Alerts',
          group: 0,
          onPressed: () => _push(context, const NotificationsScreen()),
        ),
        NativeBarButton(
          icon: const NativeIcon.symbol(
            'person.crop.circle',
            fallback: Icons.account_circle_outlined,
          ),
          title: 'Profile',
          group: 0,
          onPressed: () => _push(context, const ProfileScreen()),
        ),
      ],
      child: body,
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// 9 Metric Cards Grid matching the Blade / HTML order & customization
  Widget _buildMetricCards(BuildContext context, m.DashboardSummary s, bool isDark) {
    final List<Widget> cards = [];

    // 1. orders_count
    if (_cardVisibility['orders_count'] ?? true) {
      cards.add(
        StatCard(
          title: _view == 'team_data' ? 'Team total orders' : 'My total orders',
          value: '${s.totalOrders}',
          subtitle: 'Total volume recorded',
          icon: Icons.receipt_long_outlined,
          onTap: () => _push(context, const OrdersScreen()),
        ),
      );
    }

    // 2. sales_value
    if (_cardVisibility['sales_value'] ?? true) {
      cards.add(
        StatCard(
          title: _view == 'team_data' ? 'Team sales value' : 'My sales closing value',
          value: Fmt.money(s.closingValue),
          subtitle: 'Agreed deal values',
          icon: Icons.trending_up_rounded,
          onTap: () => _push(context, const OrdersScreen()),
        ),
      );
    }

    // 3. verified_revenue (Featured Card)
    if (_cardVisibility['verified_revenue'] ?? true) {
      cards.add(
        StatCard(
          title: _view == 'team_data' ? 'Team verified revenue' : 'My verified revenue',
          value: Fmt.money(s.verifiedRevenue),
          subtitle: 'Cleared and verified collections',
          featured: true,
          onTap: () => _push(context, const OrdersScreen()),
        ),
      );
    }

    // 4. customers_count
    if (_cardVisibility['customers_count'] ?? true) {
      cards.add(
        StatCard(
          title: _view == 'team_data' ? 'Team customers' : 'My customers',
          value: '${s.customersCount}',
          subtitle: 'Unique client accounts',
          icon: Icons.people_alt_outlined,
          onTap: () => _push(context, const CustomersScreen()),
        ),
      );
    }

    // 5. active_subscriptions
    if (_cardVisibility['active_subscriptions'] ?? true) {
      cards.add(
        StatCard(
          title: 'Active subscriptions',
          value: '${s.activeSubscriptions}',
          subtitle: 'Current live plans',
          icon: Icons.repeat_rounded,
          onTap: () => _push(context, const SubscriptionsScreen()),
        ),
      );
    }

    // 6. pending_payments
    if (_cardVisibility['pending_payments'] ?? true) {
      cards.add(
        StatCard(
          title: _view == 'team_data' ? 'Team pending payments' : 'My pending payments',
          value: '${s.pendingPaymentsCount} (${Fmt.money(s.pendingAmount)})',
          subtitle: 'Outstanding payment collection',
          icon: Icons.hourglass_top_rounded,
          accent: AppColors.warningLight,
          onTap: () => _push(context, const PaymentsScreen()),
        ),
      );
    }

    // 7. expiring_subscriptions
    if (_cardVisibility['expiring_subscriptions'] ?? true) {
      cards.add(
        StatCard(
          title: 'Expiring in 30 Days',
          value: '${s.expiringSubscriptions}',
          subtitle: 'Requires renewal outreach',
          icon: Icons.notification_important_outlined,
          accent: s.expiringSubscriptions > 0 ? AppColors.dangerLight : null,
          onTap: () => _push(context, const ExpiringSubscriptionsScreen()),
        ),
      );
    }

    // 8. follow_ups
    if (_cardVisibility['follow_ups'] ?? true) {
      cards.add(
        StatCard(
          title: _view == 'team_data' ? 'Team follow-ups' : 'My follow-ups',
          value: '${s.followUps}',
          subtitle: 'Scheduled client tasks',
          icon: Icons.event_note_outlined,
          onTap: () => _push(context, const FollowUpsScreen()),
        ),
      );
    }

    // 9. monthly_performance
    if (_cardVisibility['monthly_performance'] ?? true) {
      cards.add(
        StatCard(
          title: 'Monthly performance',
          value: Fmt.money(s.monthlyClosingValue),
          subtitle: '${s.monthlyOrders} orders this month',
          icon: Icons.calendar_month_outlined,
          onTap: () => _push(context, const OrdersScreen()),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 148,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => cards[i],
        );
      },
    );
  }

  /// Middle Section: My Recent Orders & Portal Actions matching web grid
  Widget _buildRecentOrdersAndActions(
    BuildContext context,
    m.Dashboard d,
    AuthController auth,
    AppServices services,
    bool isDark,
  ) {
    return Column(
      children: [
        // Card 1: My Recent Orders
        _LeadxContainerCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _view == 'team_data' ? 'Recent Team Orders' : 'My Recent Orders',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  InkWell(
                    onTap: () => _push(context, const OrdersScreen()),
                    child: Text(
                      'View all →',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF404040),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (d.recentOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No orders found in this period.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    // Table Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              'ORDER ID / PRODUCT',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'VALUE',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'STATUS',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 52),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0),
                    ),
                    for (final order in d.recentOrders)
                      _buildOrderTableRow(context, order, isDark),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 2: Portal Actions
        _LeadxContainerCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portal Actions',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF171717),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Quick shortcuts to your daily sales workflow.',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 14),
              if (_view != 'team_data') ...[
                if (auth.canCreateOrders)
                  AppPrimaryButton(
                    label: '+ Create New Order',
                    onPressed: () => showOrderCreateSheet(context, services),
                  ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: const Center(
                    child: Text(
                      'Order Creation disabled in Team Data mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              AppOutlinedButton(
                label: 'View Orders List',
                onPressed: () => _push(context, const OrdersScreen()),
              ),
              const SizedBox(height: 8),
              AppOutlinedButton(
                label: 'My Customers',
                onPressed: () => _push(context, const CustomersScreen()),
              ),
              const SizedBox(height: 8),
              AppOutlinedButton(
                label: 'My Profile',
                onPressed: () => _push(context, const ProfileScreen()),
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'LeadX Enterprise Sales Management',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    color: isDark ? const Color(0xFF737373) : const Color(0xFFA3A3A3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTableRow(BuildContext context, Order order, bool isDark) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.productNameSnapshot ?? order.productName ?? 'Standard Plan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                Fmt.money(order.closingValue),
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF171717),
                ),
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              status: order.paymentStatus.isNotEmpty
                  ? order.paymentStatus
                  : order.orderStatus,
            ),
            const SizedBox(width: 8),
            Text(
              'View →',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.brandDark : const Color(0xFF404040),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lower Section: Follow-ups & Expiring Reminders
  Widget _buildFollowUpsAndExpiring(BuildContext context, m.Dashboard d, bool isDark) {
    return Column(
      children: [
        // Follow-ups Card
        _LeadxContainerCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upcoming Client Follow-ups',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF171717),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scheduled touchpoints & retention tasks',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _push(context, const FollowUpsScreen()),
                    child: Text(
                      'All tasks →',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF404040),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0),
              ),
              if (d.recentFollowUps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No upcoming follow-ups scheduled',
                      style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                )
              else
                for (final fu in d.recentFollowUps)
                  _buildFollowUpRow(context, fu, isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Expiring Subscriptions Card
        _LeadxContainerCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expiring Subscriptions (30 Days)',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF171717),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Accounts due for renewal outreach',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _push(context, const ExpiringSubscriptionsScreen()),
                    child: Text(
                      'Expiry center →',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF404040),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0),
              ),
              if (d.expiringSubscriptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No subscriptions expiring in the next 30 days',
                      style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                )
              else
                for (final sub in d.expiringSubscriptions)
                  _buildExpiringSubRow(context, sub, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpRow(BuildContext context, m.DashboardRecentFollowUp fu, bool isDark) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FollowUpDetailScreen(followUpId: fu.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fu.title ?? 'Follow-up #${fu.id}',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customer: ${fu.customer?.name ?? 'Client'} • Priority: ${fu.priority ?? 'Normal'}',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              status: 'pending',
              label: fu.scheduledAt != null ? Fmt.dateTime(fu.scheduledAt) : 'Pending',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSubRow(BuildContext context, Subscription sub, bool isDark) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(subscriptionId: sub.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.planSnapshot ?? 'Subscription #${sub.id}',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Plan: ${sub.planSnapshot ?? 'Custom'} • Customer: ${sub.customerName ?? 'Client'}',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              status: 'danger',
              label: 'Expires ${Fmt.date(sub.expiresAt)}',
            ),
          ],
        ),
      ),
    );
  }

  /// 6-Month Sales Trajectory (Card with Chart + Table matching web)
  Widget _buildTrajectorySection(
    BuildContext context,
    List<m.DashboardChartPoint> chart,
    bool isDark,
  ) {
    return _LeadxContainerCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '6-Month Sales Trajectory',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Orders written and total agreed closing values',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
            ),
          ),
          const SizedBox(height: 14),

          // Visual Bar Chart
          _Chart(chart),
          const SizedBox(height: 14),

          // Trajectory Table
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262626) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'PERIOD',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ORDERS WRITTEN',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'TOTAL CLOSING VALUE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in chart)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      entry.month,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF171717),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${entry.orders}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      Fmt.money(entry.closingValue),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF171717),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// LeadX Employee Portal Footer matching employee.blade.php
  Widget _buildEmployeeFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ${DateTime.now().year} LeadX. Employee Portal.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              color: isDark ? const Color(0xFF737373) : const Color(0xFFA3A3A3),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Session Active',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top bar in the main content matching the Blade top block in employee-dashboard-preview.html
class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.employeeName,
    required this.username,
    required this.teamName,
    required this.view,
    required this.greeting,
  });

  final String employeeName;
  final String username;
  final String teamName;
  final String view;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final date = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final hour = now.hour;
    final timeIcon = hour < 12
        ? Icons.wb_sunny_outlined
        : (hour < 17 ? Icons.wb_twilight_outlined : Icons.nightlight_outlined);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              timeIcon,
              size: 13,
              color: isDark ? AppColors.brandDark : AppColors.brand,
            ),
            const SizedBox(width: 5),
            Text(
              '$greeting, $employeeName',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 10, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          view == 'team_data'
              ? 'Team Performance Dashboard'
              : 'My Sales Dashboard',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF171717),
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
            ),
            children: [
              TextSpan(text: '$employeeName ($username) • Team: '),
              TextSpan(
                text: teamName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF404040),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Standard LeadX surface card with 12px radius, light grey border and subtle shadow
class _LeadxContainerCard extends StatelessWidget {
  const _LeadxContainerCard({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Banner shown when viewing Team Data mode (View-Only) matching dashboard.blade.php
class _TeamDataModeAlert extends StatelessWidget {
  const _TeamDataModeAlert({required this.onSwitchToMyData});

  final VoidCallback onSwitchToMyData;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(
          color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE0E7FF) : const Color(0xFF312E81),
                    ),
                    children: const [
                      TextSpan(
                        text: 'Team Data Mode (View-Only): ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Displaying aggregate team metrics. Creation, editing, approvals, and deletions are strictly disabled.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onSwitchToMyData,
              child: Text(
                'Switch to My Data →',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet inline notice shown when the API denies team_data and the screen
/// falls back to the My Data payload — informational, never an error state.
class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(
            alpha: cs.brightness == Brightness.dark ? 0.08 : 0.04,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
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
}

/// One circular action inside the floating dock.
class _DockAction extends StatelessWidget {
  const _DockAction(
    this.context, {
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final BuildContext context;
  final Widget icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = primary ? cs.primary : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary
                  ? (isDark ? AppColors.brandDark : AppColors.brand)
                  : cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.07),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: primary ? Colors.white : accent,
                  size: 20,
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spec §4.1: Collected vs Due card showing collected revenue, due/pending amount and conversion progress.
class _CollectedVsDueCard extends StatelessWidget {
  const _CollectedVsDueCard({required this.summary, required this.onTap});

  final m.DashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final collected = summary.verifiedRevenue;
    final due = summary.pendingAmount > 0
        ? summary.pendingAmount
        : (summary.closingValue - collected).clamp(0.0, double.infinity);
    final total = collected + due;
    final ratio = total > 0 ? (collected / total).clamp(0.0, 1.0) : 1.0;
    final percent = (ratio * 100).toInt();

    return AppCard.surface(
      context,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StatusPalette.success(cs).withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payments_rounded,
                      size: 13,
                      color: StatusPalette.success(cs),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'COLLECTED VS DUE',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: StatusPalette.success(cs),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$percent% Settled',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected Revenue',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.money(collected),
                      style: AppTypography.statNumeric.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: StatusPalette.success(cs),
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Due / Pending',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.money(due),
                      style: AppTypography.statNumericSmall.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: due > 0 ? StatusPalette.warning(cs) : cs.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Conversion progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: StatusPalette.warning(cs).withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                StatusPalette.success(cs),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Pipeline closing: ${Fmt.money(summary.closingValue)}',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${summary.totalOrders} total orders',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A clean 6-month bar chart drawn with plain widgets (no shader cost).
class _Chart extends StatelessWidget {
  const _Chart(this.points);

  final List<m.DashboardChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final maxOrders = points.isEmpty
        ? 1
        : points
              .map((p) => p.orders)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 99999);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(
          color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.brandDark : AppColors.brand)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: isDark ? AppColors.brandDark : AppColors.brand,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Monthly Order Volume',
                style: AppTypography.cardTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Text(
                  'Last 6 mo',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < points.length; i++)
                _chartBar(
                  p: points[i],
                  isLast: i == points.length - 1,
                  maxOrders: maxOrders,
                  cs: cs,
                  isDark: isDark,
                ),
            ],
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Current month activity',
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${points.last.orders} orders',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  Fmt.money(points.last.closingValue),
                  style: AppTypography.statNumericSmall.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.brandDark : AppColors.brand,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartBar({
    required m.DashboardChartPoint p,
    required bool isLast,
    required int maxOrders,
    required ColorScheme cs,
    required bool isDark,
  }) {
    final heightFactor = (p.orders / maxOrders).clamp(0.06, 1.0);

    return Expanded(
      child: Column(
        children: [
          Text(
            '${p.orders}',
            style: AppTypography.statNumericSmall.copyWith(
              fontSize: 11,
              fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
              color: isLast
                  ? (isDark ? AppColors.brandDark : AppColors.brand)
                  : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 74,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    color: isLast
                        ? (isDark ? AppColors.brandDark : AppColors.brand)
                        : cs.primary.withValues(alpha: isDark ? 0.45 : 0.35),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    boxShadow: isLast
                        ? const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLast ? 6 : 2,
              vertical: isLast ? 2 : 0,
            ),
            decoration: isLast
                ? BoxDecoration(
                    color: (isDark ? AppColors.brandDark : AppColors.brand)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              p.month,
              style: AppTypography.caption.copyWith(
                color: isLast
                    ? (isDark ? AppColors.brandDark : AppColors.brand)
                    : cs.onSurfaceVariant,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

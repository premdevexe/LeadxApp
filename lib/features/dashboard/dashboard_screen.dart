import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The employee dashboard: summary figures, metric cards, recent orders,
/// follow-ups, expiring subscriptions and a 6-month sales trajectory.
/// Every figure formats through the admin currency config.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  m.Dashboard? _data;
  bool _loading = true;
  String? _error;

  /// Customization state for the metric cards. Persisted to local storage so
  /// the layout choice survives a reload / app restart.
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

  static const _cardVisibilityPrefKey = 'dashboard_card_visibility_v1';

  @override
  void initState() {
    super.initState();
    _loadPersistedCardVisibility();
    _load();
  }

  Future<void> _loadPersistedCardVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getStringList(_cardVisibilityPrefKey) ?? const <String>[];
      if (raw.isEmpty) return;
      // A key present in the list = hidden; anything unlisted stays visible.
      final hidden = raw.toSet();
      setState(() {
        for (final key in _cardVisibility.keys) {
          _cardVisibility[key] = !hidden.contains(key);
        }
      });
    } catch (_) {
      // Preferences unavailable — keep the defaults.
    }
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _data == null;
      _error = null;
    });

    try {
      context.read<AppConfigService>().refresh();
      final res = await services.api.dashboard();
      if (!mounted) return;
      final parsed = m.Dashboard.fromJson(res);
      setState(() {
        _data = parsed;
        _loading = false;
      });
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetwork || e.isTimeout ? 'No connection. Retrying…' : e.message;
        _loading = false;
      });
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

  /// Opens a real notifications panel backed by the `employee/notifications`
  /// endpoint (the bell previously just popped a snackbar with the newest
  /// item). The list loads the full unread set, supports per-item and
  /// mark-all read, and re-reads when reopened.
  Future<void> _showNotificationsPanel() async {
    final services = context.read<AppServices>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusLg)),
      ),
      builder: (_) => _NotificationsPanel(
        services: services,
        initialUnread: _data?.recentNotifications.where((n) => !n.isRead).length ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final auth = context.watch<AuthController>();
    final employeeName = auth.me?.data.name ?? 'Employee';
    final unreadCount = _data?.recentNotifications.where((n) => !n.isRead).length ?? 0;
    final notifications = _data?.recentNotifications ?? const <m.DashboardRecentNotification>[];

    // Header total height = status bar inset + 56px bar.
    final headerHeight = MediaQuery.paddingOf(context).top + 56;

    // The whole strip — status-bar inset + 56px bar — must be opaque: the
    // page scrolls underneath it, and any transparent zone shows the
    // content through, smearing the top of the screen while scrolling.
    final header = Container(
      color: isDark ? const Color(0xFF171717) : Colors.white,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: LeadxNavHeader(
        employeeName: employeeName,
        unreadCount: unreadCount,
        // Opens the shell's navigation drawer when one is present (the
        // dashboard is a tab under HomeShell).
        onMenuTap: Scaffold.maybeOf(context)?.hasDrawer == true
            ? () => Scaffold.of(context).openDrawer()
            : null,
        onRefresh: _load,
        onNotifications: notifications.isEmpty ? null : _showNotificationsPanel,
        onLogout: () => _confirmLogout(context, auth),
      ),
    );

    Widget body;
    if (_loading && _data == null) {
      body = const LoadingScreen();
    } else if (_error != null && _data == null) {
      body = RefreshIndicator(
        edgeOffset: headerHeight,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, headerHeight + 16, 16, 24),
          children: [ErrorBanner(message: _error!, onRetry: _load)],
        ),
      );
    } else {
      final d = _data!;
      final s = d.summary;

      body = RefreshIndicator(
        edgeOffset: headerHeight,
        onRefresh: _load,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, headerHeight + 16, 16, 24),
          children: [
            // ── Page title ─────────────────────────────────────────
            Text(
              'My dashboard',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF171717),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$employeeName • Individual performance',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notices ────────────────────────────────────────────
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

            // ── Collected vs Due (the one featured figure) ────────
            _CollectedVsDueCard(summary: s),
            const SizedBox(height: 16),

            // ── Metric cards ───────────────────────────────────────
            _buildMetricCards(context, s, isDark),
            const SizedBox(height: 24),

            // ── Recent orders ──────────────────────────────────────
            _buildRecentOrders(context, d, isDark),
            const SizedBox(height: 24),

            // ── Follow-ups & expiring ──────────────────────────────
            _buildFollowUpsAndExpiring(context, d, isDark),
            const SizedBox(height: 24),

            // ── 6-month trajectory ─────────────────────────────────
            if (d.monthlySalesChart.isNotEmpty) ...[
              _buildTrajectorySection(context, d.monthlySalesChart, isDark),
              const SizedBox(height: 24),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          body,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: header,
          ),
        ],
      ),
    );
  }

  /// The metric cards grid. Each card is a label + figure + quiet caption —
  /// no icon padding, no accent bars. Featured cards get a dark surface
  /// step, not a glow.
  Widget _buildMetricCards(BuildContext context, m.DashboardSummary s, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final cards = <_MetricCard>[
      if (_cardVisibility['orders_count'] ?? true)
        _MetricCard(
          title: 'Total orders',
          value: '${s.totalOrders}',
          subtitle: 'All time',
        ),
      if (_cardVisibility['sales_value'] ?? true)
        _MetricCard(
          title: 'Closing value',
          value: Fmt.money(s.closingValue),
          subtitle: 'Agreed deal values',
        ),
      if (_cardVisibility['verified_revenue'] ?? true)
        _MetricCard(
          title: 'Verified revenue',
          value: Fmt.money(s.verifiedRevenue),
          subtitle: 'Cleared collections',
        ),
      if (_cardVisibility['customers_count'] ?? true)
        _MetricCard(
          title: 'Customers',
          value: '${s.customersCount}',
          subtitle: 'Client accounts',
        ),
      if (_cardVisibility['active_subscriptions'] ?? true)
        _MetricCard(
          title: 'Active subscriptions',
          value: '${s.activeSubscriptions}',
          subtitle: 'Live plans',
        ),
      if (_cardVisibility['pending_payments'] ?? true)
        _MetricCard(
          title: 'Pending payments',
          value: '${s.pendingPaymentsCount} • ${Fmt.money(s.pendingAmount)}',
          subtitle: 'Outstanding',
        ),
      if (_cardVisibility['expiring_subscriptions'] ?? true)
        _MetricCard(
          title: 'Expiring in 30 days',
          value: '${s.expiringSubscriptions}',
          subtitle: 'Needs renewal outreach',
        ),
      if (_cardVisibility['follow_ups'] ?? true)
        _MetricCard(
          title: 'Follow-ups',
          value: '${s.followUps}',
          subtitle: 'Scheduled tasks',
        ),
      if (_cardVisibility['monthly_performance'] ?? true)
        _MetricCard(
          title: 'This month',
          value: Fmt.money(s.monthlyClosingValue),
          subtitle: '${s.monthlyOrders} ${s.monthlyOrders == 1 ? 'order' : 'orders'}',
        ),
    ];

    if (cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppCard.decorationOf(context),
        child: const Center(
          child: Text(
            'No cards to show. Enable some from Customize cards.',
            style: TextStyle(fontSize: 13, color: Color(0xFF737373)),
          ),
        ),
      );
    }

    // Rows instead of a GridView so an odd trailing card (e.g. 9 cards in
    // 2 columns) stretches full width on its last row instead of leaving a
    // dead empty cell beside it. 120px card height and 12px gutters match
    // the old grid metrics.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final rows = <Widget>[];
        for (int start = 0; start < cards.length; start += columns) {
          final end = start + columns < cards.length ? start + columns : cards.length;
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 12),
              child: Row(
                children: [
                  for (int i = start; i < end; i++) ...[
                    if (i > start) const SizedBox(width: 12),
                    // Each row's cards fill the width; when the last row has
                    // fewer than [columns] cards it simply spans the rest.
                    Expanded(
                      child: SizedBox(
                        height: 120,
                        child: cards[i].build(context, isDark: isDark, cs: cs),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildRecentOrders(BuildContext context, m.Dashboard d, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    const title = 'Recent orders';
    final sub = d.recentOrders.isEmpty
        ? 'No orders recorded yet'
        : '${d.recentOrders.length} most recent';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppCard.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (d.recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No orders recorded yet',
                  style: TextStyle(fontSize: 13, color: Color(0xFFA3A3A3)),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            _TableHeaderRow(isDark: isDark),
            for (final order in d.recentOrders)
              _OrderRow(order: order, isDark: isDark, cs: cs),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowUpsAndExpiring(BuildContext context, m.Dashboard d, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    // Nothing pending in either list: two big dead "no data" cards read as
    // a broken page, so they collapse into one compact, positive block.
    if (d.recentFollowUps.isEmpty && d.expiringSubscriptions.isEmpty) {
      return _AllCaughtUpCard(isDark: isDark);
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppCard.decorationOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming follow-ups',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF171717),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scheduled touchpoints and retention tasks',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 12),
              if (d.recentFollowUps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No upcoming follow-ups',
                      style: TextStyle(fontSize: 13, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                )
              else
                for (final fu in d.recentFollowUps)
                  _FollowUpRow(fu: fu, isDark: isDark, cs: cs),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppCard.decorationOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expiring subscriptions',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF171717),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Accounts due for renewal in 30 days',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 12),
              if (d.expiringSubscriptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nothing expiring in the next 30 days',
                      style: TextStyle(fontSize: 13, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                )
              else
                for (final sub in d.expiringSubscriptions)
                  _ExpiringSubRow(sub: sub, isDark: isDark, cs: cs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrajectorySection(
    BuildContext context,
    List<m.DashboardChartPoint> chart,
    bool isDark,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppCard.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales trajectory',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Orders and closing value over the last 6 months',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
            ),
          ),
          const SizedBox(height: 16),

          _Chart(chart, isDark: isDark, cs: cs),
        ],
      ),
    );
  }
}

/// Shown instead of two dead "no data" cards when there are neither
/// scheduled follow-ups nor expiring subscriptions: a single compact,
/// positive confirmation — an invitation to act, not an empty mood.
class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final success = StatusPalette.success(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: AppCard.decorationOf(context),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: success.withValues(alpha: isDark ? 0.22 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 20, color: success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're all caught up",
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF171717),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No follow-ups scheduled and no subscriptions due for renewal.',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small building blocks ───────────────────────────────────────────────────

class _MetricCard {
  _MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;

  /// Uniform white card: the grid is deliberately flat (clean & minimal
  /// direction), so no card gets a dark step or glow.
  Widget build(BuildContext context, {required bool isDark, required ColorScheme cs}) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final border = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5);
    final titleColor = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);
    final valueColor = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF171717);
    final subtitleColor = isDark ? const Color(0xFF888888) : const Color(0xFFA3A3A3);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: titleColor,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
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
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                color: subtitleColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Column widths shared by the header and every order row so the three
/// columns stay vertically aligned and nothing overflows on narrow phones.
class _OrderColumns {
  static const double valueWidth = 72;
  static const double statusWidth = 80;
  static const double gap = 8;
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);
    TextStyle label() => TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text('Order', style: label())),
          const SizedBox(width: _OrderColumns.gap),
          SizedBox(
            width: _OrderColumns.valueWidth,
            child: Align(alignment: Alignment.centerRight, child: Text('Value', style: label())),
          ),
          const SizedBox(width: _OrderColumns.gap),
          SizedBox(
            width: _OrderColumns.statusWidth,
            child: Align(alignment: Alignment.centerRight, child: Text('Status', style: label())),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.isDark, required this.cs});

  final Order order;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
    final ink = isDark ? Colors.white : const Color(0xFF171717);
    final muted = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: divider),
        ),
      ),
      child: Row(
        children: [
          // Order number + product take whatever room is left; they
          // ellipsize instead of pushing the value/status columns off.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.productNameSnapshot ?? order.productName ?? 'Standard plan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _OrderColumns.gap),
          SizedBox(
            width: _OrderColumns.valueWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                Fmt.money(order.closingValue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
          ),
          const SizedBox(width: _OrderColumns.gap),
          SizedBox(
            width: _OrderColumns.statusWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(
                status:
                    order.paymentStatus.isNotEmpty ? order.paymentStatus : order.orderStatus,
                compact: true,
                ellipsize: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.fu, required this.isDark, required this.cs});

  final m.DashboardRecentFollowUp fu;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
    final ink = isDark ? Colors.white : const Color(0xFF171717);
    final muted = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fu.customer?.name ?? 'Client'} • ${fu.priority ?? 'Normal'} priority',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Flexible + ellipsized label so a long "dd MMM yyyy, HH:mm"
          // date can never overflow the row on a narrow screen.
          Flexible(
            child: StatusBadge(
              status: 'pending',
              label: fu.scheduledAt != null ? Fmt.dateTime(fu.scheduledAt) : 'Pending',
              compact: true,
              ellipsize: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiringSubRow extends StatelessWidget {
  const _ExpiringSubRow({required this.sub, required this.isDark, required this.cs});

  final Subscription sub;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
    final ink = isDark ? Colors.white : const Color(0xFF171717);
    final muted = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.customerName ?? 'Client'} • expires ${Fmt.date(sub.expiresAt)}',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: StatusBadge(
              status: 'danger',
              label: 'Expires ${Fmt.date(sub.expiresAt)}',
              compact: true,
              ellipsize: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectedVsDueCard extends StatelessWidget {
  const _CollectedVsDueCard({required this.summary});

  final m.DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final collected = summary.verifiedRevenue;
    final due = summary.pendingAmount > 0
        ? summary.pendingAmount
        : (summary.closingValue - collected).clamp(0.0, double.infinity);
    final total = collected + due;
    // When there is genuinely nothing collected or due, the card should read
    // "no activity", not a full green bar and a fake "100% settled".
    final hasActivity = total > 0;
    final ratio = hasActivity ? (collected / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).toInt();

    return AppCard.surface(
      context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Neutral chip: the accent is reserved for the number and the
              // progress fill below (one place for the color).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payments_rounded,
                      size: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Collected vs due',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
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
                  hasActivity ? '$percent% settled' : 'No activity yet',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected revenue',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.money(collected),
                      style: AppTypography.statNumeric.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        // The single accent on the page: the one number that
                        // matters most, in the web secondary accent.
                        color: AppColors.emeraldAccent,
                        letterSpacing: -0.4,
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
                      'Due / pending',
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
                        color: cs.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.emeraldAccent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Closing value ${Fmt.money(summary.closingValue)}',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${summary.totalOrders} orders',
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

/// A muted 6-month bar chart drawn with plain widgets.
class _Chart extends StatelessWidget {
  const _Chart(this.points, {required this.isDark, required this.cs});

  final List<m.DashboardChartPoint> points;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final maxOrders = points.isEmpty
        ? 1
        : points
            .map((p) => p.orders)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 99999);

    final barBase = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5);
    // The page's single accent: the current-month bar (and its footer
    // figures) share the indigo used on the hero card — one place for
    // color, everything else neutral.
    final barAccent =
        isDark ? const Color(0xFFA5B4FC) : AppColors.emeraldAccent;

    // No inner card: the section already sits in an AppCard, so the chart
    // draws directly on the card surface (card-in-card read as heavy).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Monthly orders',
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              'Last 6 months',
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < points.length; i++)
              _chartBar(
                p: points[i],
                isLast: i == points.length - 1,
                maxOrders: maxOrders,
                barBase: barBase,
                barAccent: barAccent,
              ),
          ],
        ),
        if (points.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                points.last.month.isNotEmpty ? points.last.month : 'Latest',
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${points.last.orders} ${points.last.orders == 1 ? 'order' : 'orders'} • ${Fmt.money(points.last.closingValue)}',
                style: AppTypography.statNumericSmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: barAccent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chartBar({
    required m.DashboardChartPoint p,
    required bool isLast,
    required int maxOrders,
    required Color barBase,
    required Color barAccent,
  }) {
    final isZero = p.orders == 0;
    final heightFactor = isZero ? 0.0 : (p.orders / maxOrders).clamp(0.12, 1.0);
    final color = isLast ? barAccent : barBase;

    return Expanded(
      child: Column(
        children: [
          Text(
            '${p.orders}',
            style: AppTypography.statNumericSmall.copyWith(
              fontSize: 11,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
              color: isLast ? barAccent : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: isZero
                  ? // Empty months get a small baseline tick, not a broken
                    // sliver — every column reads as "0" on purpose.
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: barBase,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : FractionallySizedBox(
                      heightFactor: heightFactor,
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // Short month name only ("Nov"): the full "Nov 2026" label is
          // wider than a 6th-of-the-row and collides with its neighbours.
          // The footer line below already carries the full month + figures.
          Text(
            p.month.split(' ').first.isEmpty ? p.month : p.month.split(' ').first,
            style: AppTypography.caption.copyWith(
              color: isLast ? barAccent : cs.onSurfaceVariant,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet notifications list: fetches the full unread set from the
/// notifications endpoint, supports per-item and mark-all read.
class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel({
    required this.services,
    required this.initialUnread,
  });

  final AppServices services;
  final int initialUnread;

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.services.api.notifications(perPage: 50);
      if (!mounted) return;
      setState(() {
        _items = (res['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notifications. Pull to retry.';
      });
    }
  }

  Future<void> _markRead(int index, String id) async {
    try {
      await widget.services.api.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        _items[index] = {..._items[index], 'read_at': DateTime.now().toIso8601String()};
      });
    } catch (_) {
      // Quiet failure — the list already shows the item.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.services.api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _items.length; i++) {
          if (_items[i]['read_at'] == null) {
            _items[i] = {..._items[i], 'read_at': DateTime.now().toIso8601String()};
          }
        }
      });
    } catch (_) {}
  }

  bool _isRead(Map<String, dynamic> n) => n['read_at'] != null;

  String _titleOf(Map<String, dynamic> n) {
    final data = n['data'] as Map<String, dynamic>? ?? const {};
    return (data['title'] as String?) ??
        ((n['type'] as String? ?? 'Notification').split('.').last);
  }

  String _messageOf(Map<String, dynamic> n) {
    final data = n['data'] as Map<String, dynamic>? ?? const {};
    final msg = data['message'] as String?;
    return (msg == null || msg.isEmpty) ? '—' : msg;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final ink = isDark ? Colors.white : const Color(0xFF171717);
    final muted = isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373);
    final divider = isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
    final unread = _items.where((n) => !_isRead(n)).length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(bottom: BorderSide(color: divider)),
              ),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (unread > 0)
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: LeadxFlickrLoading(size: 32))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    style: TextStyle(
                                        fontSize: 13, color: muted)),
                                const SizedBox(height: 12),
                                AppPrimaryButton(
                                  label: 'Retry',
                                  onPressed: _load,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                'No notifications yet',
                                style: TextStyle(fontSize: 13, color: muted),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final n = _items[i];
                                final read = _isRead(n);
                                return InkWell(
                                  onTap: read
                                      ? null
                                      : () => _markRead(i, n['id'] as String),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              margin: const EdgeInsets.only(
                                                  top: 6),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: read
                                                    ? divider
                                                    : const Color(0xFFDC2626),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _titleOf(n),
                                                style: TextStyle(
                                                  fontFamily: AppTypography
                                                      .fontFamily,
                                                  fontSize: 13,
                                                  fontWeight: read
                                                      ? FontWeight.w500
                                                      : FontWeight.w600,
                                                  color: read ? muted : ink,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 17),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _messageOf(n),
                                                style: TextStyle(
                                                  fontFamily:
                                                      AppTypography
                                                          .fontFamily,
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              if (n['created_at'] != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  Fmt.relative(n['created_at']
                                                      as String?),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.outlineVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

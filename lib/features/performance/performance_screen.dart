import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/models/analytics.dart' as m;
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';

/// The employee's performance report — mirrors the backend
/// `GET /employee/analytics` (module 12 of the admin web portal): a KPI
/// overview, a 6-month revenue/order bar chart and the product breakdown.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  m.EmployeeAnalytics? _data;
  bool _loading = true;
  String? _error;
  bool _forbidden = false;
  String _view = 'my_data';
  bool _teamDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _data == null;
      _error = null;
      _forbidden = false;
    });

    try {
      final res = await services.api.analytics();
      final analytics = m.EmployeeAnalytics.fromJson(res);
      if (!mounted) return;
      setState(() {
        _data = analytics;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _forbidden = e.isForbidden;
        _error = e.isNetwork || e.isTimeout ? 'No connection. Retrying…' : e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    final auth = context.watch<AuthController>();
    final employeeName = auth.me?.data.name;

    // employee/analytics is scoped strictly to this employee server-side —
    // there is no team_data view (team analytics is a separate team-portal
    // endpoint), so the header states the personal scope explicitly.
    final subtitle = [
      if (employeeName != null && employeeName.isNotEmpty) employeeName,
      'Your performance · last 6 months',
    ].join(' · ');

    Widget body;
    if (_loading && _data == null) {
      body = const LoadingScreen();
    } else if (_forbidden) {
      // 403: not a crash — a plain not-allowed card.
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: AppCard.surface(
            context,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 32, color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  "You don't have access to performance reports",
                  textAlign: TextAlign.center,
                  style: AppTypography.cardTitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact your manager to request report access.',
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary.copyWith(
                      color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_error != null && _data == null) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [ErrorBanner(message: _error!, onRetry: _load)],
        ),
      );
    } else {
      final d = _data!;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.paddingOf(context).top + 12, 16, 96),
          children: [
            // ── My Data / Team Data scope (§3) ───────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DataScopeSegmentControl(
                selectedView: _view,
                onChanged: (next) {
                  if (next == _view) return;
                  if (next == 'team_data' && !auth.hasTeamDataAccess) {
                    setState(() {
                      _view = 'my_data';
                      _teamDenied = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Team Data requires admin grant. Showing My Data.')),
                    );
                    return;
                  }
                  setState(() {
                    _view = next;
                    _teamDenied = false;
                  });
                  _load();
                },
              ),
            ),
            if (_teamDenied) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: cs.brightness == Brightness.dark ? 0.08 : 0.04),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Team reports require an admin grant — showing your data',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (d.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        size: 40,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No performance data yet for this period',
                        style: AppTypography.cardTitle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _kpiGrid(context, d.overview),
              const SizedBox(height: 16),
              if (d.monthly.isNotEmpty) ...[
                AppCard.section(context, 'Revenue · last 6 months'),
                _RevenueChart(d.monthly),
                const SizedBox(height: 16),
              ],
              if (d.products.isNotEmpty) ...[
                AppCard.section(context, 'Product breakdown'),
                _ProductList(d.products),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      body: NativeNavigationBar(
        leading: canPop
            ? NativeBarButton(
                icon: const NativeIcon.symbol('chevron.left',
                    fallback: Icons.arrow_back),
                title: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: NativeBarTitle(
          title: 'Performance Report',
          subtitle: subtitle,
          capsule: true,
          icon: const NativeIcon.symbol('chart.bar.xaxis',
              fallback: Icons.insights_outlined),
        ),
        child: body,
      ),
    );
  }

  Widget _kpiGrid(BuildContext context, m.AnalyticsOverview o) {
    final cs = Theme.of(context).colorScheme;

    final primary = cs.primary;
    final tiles = [
      (
        'Verified revenue',
        o.verifiedRevenue,
        Icons.verified_rounded,
        StatusPalette.success(cs),
        'Secured & settled',
      ),
      (
        'Orders closed',
        '${o.totalOrders}',
        Icons.receipt_long_rounded,
        primary,
        'Total orders',
      ),
      (
        'Pending collections',
        o.pendingCollections,
        Icons.hourglass_top_rounded,
        StatusPalette.warning(cs),
        'Awaiting settlement',
      ),
      (
        'Active subscriptions',
        '${o.activeSubscriptions}',
        Icons.credit_card_rounded,
        primary,
        'Recurring revenue',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 104,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final (label, value, icon, color, subtitle) = tiles[i];
        return AppCard.stat(
          context,
          label: label,
          value: value,
          icon: icon,
          color: color,
          subtitle: subtitle,
        );
      },
    );
  }
}

/// A 6-month revenue + orders bar chart drawn with plain widgets (no chart
/// package) — the dashboard's `_Chart` pattern: FractionallySizedBox bars,
/// a per-bar figure row and a month label row.
class _RevenueChart extends StatelessWidget {
  const _RevenueChart(this.points);

  final List<m.AnalyticsMonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxRevenue = points.isEmpty
        ? 0.0
        : points.map((p) => p.revenueValue).reduce((a, b) => a > b ? a : b);
    final maxOrders = points.isEmpty
        ? 0
        : points.map((p) => p.orders).reduce((a, b) => a > b ? a : b);

    return AppCard.surface(
      context,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: StatusPalette.info(cs).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: StatusPalette.info(cs),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Monthly revenue',
                style: AppTypography.cardTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: StatusPalette.info(cs),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Revenue',
                      style: AppTypography.caption.copyWith(
                          fontSize: 10.5, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Orders',
                      style: AppTypography.caption.copyWith(
                          fontSize: 10.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < points.length; i++)
                _bar(
                  p: points[i],
                  isLast: i == points.length - 1,
                  maxRevenue: maxRevenue,
                  maxOrders: maxOrders,
                  cs: cs,
                ),
            ],
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
                height: 1,
                color: cs.outlineVariant
                    .withValues(alpha: cs.brightness == Brightness.dark ? 0.15 : 0.4)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Latest month (${points.last.label})',
                  style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${points.last.orders} orders',
                  style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
                const SizedBox(width: 10),
                Text(
                  points.last.revenue,
                  style: AppTypography.statNumericSmall.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: StatusPalette.info(cs),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar({
    required m.AnalyticsMonthlyPoint p,
    required bool isLast,
    required double maxRevenue,
    required int maxOrders,
    required ColorScheme cs,
  }) {
    final revenueFactor = maxRevenue <= 0
        ? 0.06
        : (p.revenueValue / maxRevenue).clamp(0.06, 1.0);
    final ordersFactor = maxOrders <= 0
        ? 0.06
        : (p.orders.toDouble() / maxOrders).clamp(0.06, 1.0);

    // Shorten the revenue figure for the per-bar caption ("$1.2K"-style).
    final compact = _compact(p.revenueValue);

    return Expanded(
      child: Column(
        children: [
          Text(
            compact,
            style: AppTypography.statNumericSmall.copyWith(
              fontSize: 10,
              fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
              color: isLast ? StatusPalette.info(cs) : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 74,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FractionallySizedBox(
                  heightFactor: revenueFactor,
                  child: Container(
                    width: 12,
                    decoration: BoxDecoration(
                      color: StatusPalette.info(cs)
                          .withValues(alpha: isLast ? 1 : 0.75),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                FractionallySizedBox(
                  heightFactor: ordersFactor,
                  child: Container(
                    width: 12,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant
                          .withValues(alpha: isLast ? 0.55 : 0.35),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isLast ? 6 : 2, vertical: isLast ? 2 : 0),
            decoration: isLast
                ? BoxDecoration(
                    color: StatusPalette.info(cs).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              p.label.isEmpty ? p.month : p.label,
              style: AppTypography.caption.copyWith(
                color: isLast ? StatusPalette.info(cs) : cs.onSurfaceVariant,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "12345.67" → "12.3K" / "1.5M" — bar captions stay narrow.
  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

/// The per-product report: top rows with name + orders + revenue.
class _ProductList extends StatelessWidget {
  const _ProductList(this.rows);

  final List<m.AnalyticsProductRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Top 8 by revenue; rows with no orders fall to the bottom.
    final sorted = [...rows]
      ..sort((a, b) => b.revenueValue.compareTo(a.revenueValue));
    final top = sorted.take(8).toList();

    return AppCard.surface(
      context,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Product',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.6,
                      )),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Orders',
                      textAlign: TextAlign.end,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.6,
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Revenue',
                      textAlign: TextAlign.end,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.6,
                      )),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          for (final row in top)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: cs.onSurface,
                          ),
                        ),
                        if (row.activeSubscriptions > 0)
                          Text(
                            '${row.activeSubscriptions} active sub${row.activeSubscriptions > 1 ? 's' : ''} · ${row.activeCustomers} customers',
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${row.orders}',
                      textAlign: TextAlign.end,
                      style: AppTypography.statNumericSmall.copyWith(
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.collectedRevenue,
                      textAlign: TextAlign.end,
                      style: AppTypography.statNumericSmall.copyWith(
                        fontSize: 13,
                        color: cs.onSurface,
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
}

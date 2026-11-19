import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../follow_ups/follow_up_create_sheet.dart';
import '../orders/order_detail_screen.dart';
import 'subscription_detail_screen.dart';

/// Page 7: `employee/subscriptions/expiring` — Subscriptions expiring in the next 30 days.
class ExpiringSubscriptionsScreen extends StatefulWidget {
  const ExpiringSubscriptionsScreen({super.key});

  @override
  State<ExpiringSubscriptionsScreen> createState() =>
      _ExpiringSubscriptionsScreenState();
}

class _ExpiringSubscriptionsScreenState
    extends State<ExpiringSubscriptionsScreen> {
  List<Subscription> _items = [];
  ListMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _view = 'my_data';
  String _searchQuery = '';

  List<Subscription> get _filteredItems {
    if (_searchQuery.trim().isEmpty) return _items;
    final q = _searchQuery.trim().toLowerCase();
    return _items.where((s) =>
      (s.planSnapshot ?? '').toLowerCase().contains(q) ||
      (s.customerName ?? '').toLowerCase().contains(q) ||
      (s.orderNumber ?? '').toLowerCase().contains(q)
    ).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });

    try {
      final res = await services.api
          .expiringSubscriptions(view: _view, page: _page, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _items =
          data.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
      _meta = ListMeta.fromJson((res['meta'] as Map<String, dynamic>?));
      if (!mounted) return;
      setState(() {
        _loading = false;
        // When the server downgrades team_data to my_data (meta.warning
        // set), fall back to the My Data view so the segment/subtitle stay
        // honest; PaginatedList renders the unobtrusive notice.
        if ((_meta!.warning ?? '').trim().isNotEmpty) _view = 'my_data';
      });
    } on ApiException catch (e) {
      if (_view == 'team_data' && (e.isForbidden || e.isNotFound)) {
        _view = 'my_data';
        try {
          final res = await services.api
              .expiringSubscriptions(view: 'my_data', page: _page, perPage: 20);
          final data = (res['data'] as List<dynamic>?) ?? const [];
          _items =
              data.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
          _meta = ListMeta.fromJson((res['meta'] as Map<String, dynamic>?));
          if (!mounted) return;
          setState(() {
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team Data requires admin grant. Showing My Data.')),
          );
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_meta == null || _page >= _meta!.lastPage) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final services = context.read<AppServices>();
    try {
      final res = await services.api
          .expiringSubscriptions(view: _view, page: nextPage, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more =
          data.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _items.addAll(more);
        _page = nextPage;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: NativeNavigationBar(
        leading: canPop
            ? NativeBarButton(
                icon: const NativeIcon.symbol('chevron.left', fallback: Icons.arrow_back),
                title: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: NativeBarTitle(
          title: 'Expiring Soon',
          subtitle: '${_items.length} due in 30d · ${_view == 'team_data' ? 'Team' : 'Mine'}',
          capsule: true,
          icon: const NativeIcon.symbol('clock.badge.exclamationmark', fallback: Icons.hourglass_top_outlined),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
            title: 'Refresh',
            onPressed: _load,
          ),
          if (auth.hasTeamDataAccess)
            NativeBarButton(
              icon: const NativeIcon.symbol('arrow.left.arrow.right', fallback: Icons.swap_horiz),
              title: 'Scope',
              menu: [
                NativeMenuItem(
                  title: 'My Expiring',
                  checked: _view == 'my_data',
                  onSelected: () {
                    setState(() {
                      _view = 'my_data';
                      _page = 1;
                    });
                    _load();
                  },
                ),
                NativeMenuItem(
                  title: 'Team Expiring',
                  checked: _view == 'team_data',
                  onSelected: () {
                    setState(() {
                      _view = 'team_data';
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ],
            ),
        ],
        child: Builder(
          builder: (context) {
            final pad = MediaQuery.paddingOf(context);
            final content = _loading && _items.isEmpty
                ? const LoadingScreen()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _error != null && _items.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ErrorBanner(message: _error!, onRetry: _load),
                            ],
                          )
                        : Column(
                            children: [
                              // ── My Data / Team Data scope (§3) ───────────────────
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: DataScopeSegmentControl(
                                  selectedView: _view,
                                  onChanged: (next) {
                                    if (next == _view) return;
                                    setState(() {
                                      _view = next;
                                      _page = 1;
                                    });
                                    _load();
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: LeadGlassSearchField(
                                  placeholder: 'Search expiring plan or customer…',
                                  onChanged: (q) => setState(() => _searchQuery = q),
                                ),
                              ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: AppCard.surface(
                            context,
                            padding: const EdgeInsets.all(12),
                            color: StatusPalette.warning(cs).withValues(alpha: 0.12),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: StatusPalette.warning(cs)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Showing accounts renewing within 30 days. Proactive outreach boosts retention.',
                                    style: AppTypography.secondary.copyWith(
                                      color: StatusPalette.warning(cs),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: PaginatedList(
                            items: _filteredItems,
                            meta: _meta,
                            onLoadMore: _loadMore,
                            loadingMore: _loadingMore,
                            emptyTitle: _searchQuery.isNotEmpty
                                ? 'No matching expiring plans'
                                : 'No expiring subscriptions',
                            emptySubtitle: _searchQuery.isNotEmpty
                                ? 'Try refining your search keyword.'
                                : 'No subscriptions are due to expire in the next 30 days.',
                            emptyIcon: Icons.task_alt,
                            tile: (context, s, i) {
                              final accent = StatusPalette.danger(cs);
                              return NativeContextMenu(
                                borderRadius: BorderRadius.circular(14),
                                items: [
                                  NativeMenuItem(
                                    title: 'View Subscription',
                                    icon: const NativeIcon.symbol('arrow.right.circle', fallback: Icons.arrow_forward),
                                    onSelected: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SubscriptionDetailScreen(
                                                  subscriptionId: s.id),
                                        ),
                                      );
                                    },
                                  ),
                                  if (s.orderId > 0)
                                    NativeMenuItem(
                                      title: 'View Order #${s.orderId}',
                                      icon: const NativeIcon.symbol('cart', fallback: Icons.shopping_bag_outlined),
                                      onSelected: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => OrderDetailScreen(orderId: s.orderId),
                                          ),
                                        );
                                      },
                                    ),
                                  if (s.customerId != null && s.customerId! > 0)
                                    NativeMenuItem(
                                      title: 'Schedule Renewal Task',
                                      icon: const NativeIcon.symbol('calendar.badge.plus', fallback: Icons.add_task),
                                      onSelected: () => showFollowUpCreateSheet(context, preselectedCustomerId: s.customerId),
                                    ),
                                  NativeMenuItem(
                                    title: 'Copy Expiry Details',
                                    icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                                    onSelected: () {
                                      final text = '${s.planSnapshot ?? 'Subscription #${s.id}'} - ${s.customerName ?? 'Customer'} expires ${Fmt.date(s.expiresAt)}';
                                      Clipboard.setData(ClipboardData(text: text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Copied "$text" to clipboard')),
                                      );
                                    },
                                  ),
                                ],
                                child: AppCard.surface(
                                  context,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                accent.withValues(alpha: 0.14),
                                            child: Icon(Icons.timer_outlined,
                                                color: accent, size: 16),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              s.planSnapshot ??
                                                  'Subscription #${s.id}',
                                              style: AppTypography.cardTitle
                                                  .copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      color: cs.onSurface),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  accent.withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppColors.radiusSm),
                                            ),
                                            child: Text(
                                              Fmt.relative(s.expiresAt),
                                              style: AppTypography.caption.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${s.customerName ?? 'Customer'} · Order #${s.orderId}',
                                                    style: AppTypography.secondary
                                                        .copyWith(
                                                            color: cs.onSurface)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Expires on ${Fmt.date(s.expiresAt)}',
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                          color: cs.onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right,
                                              color: cs.onSurfaceVariant),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SubscriptionDetailScreen(
                                                subscriptionId: s.id),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            );
            return Padding(
              padding: EdgeInsets.only(top: pad.top),
              child: content,
            );
          },
        ),
      ),
    );
  }
}

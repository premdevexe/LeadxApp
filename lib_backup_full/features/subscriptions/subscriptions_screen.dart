import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../orders/order_detail_screen.dart';
import '../search/global_search_screen.dart';
import 'expiring_subscriptions_screen.dart';
import 'subscription_detail_screen.dart';

/// Page 5: `employee/subscriptions` — Customer subscriptions under employee or team scope.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Subscription> _items = [];
  ListMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _view = 'my_data';
  String _statusFilter = '';
  int _statusIndex = 0;
  String _searchQuery = '';

  static const _statusKeys = ['', 'active', 'expiring', 'expired', 'cancelled'];

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
      final res = await services.api.subscriptions(
        view: _view,
        status: _statusFilter.isEmpty ? null : _statusFilter,
        page: _page,
        perPage: 20,
      );
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
          final res = await services.api.subscriptions(
            view: 'my_data',
            status: _statusFilter.isEmpty ? null : _statusFilter,
            page: _page,
            perPage: 20,
          );
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
      final res = await services.api.subscriptions(
        view: _view,
        status: _statusFilter.isEmpty ? null : _statusFilter,
        page: nextPage,
        perPage: 20,
      );
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
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canPop = Navigator.of(context).canPop();
    final displayedItems = _filteredItems;

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
          title: 'Subscriptions',
          subtitle: '${_items.length} accounts · ${_view == 'team_data' ? 'Team' : 'Mine'}',
          capsule: true,
          icon: const NativeIcon.symbol('arrow.triangle.2.circlepath', fallback: Icons.repeat),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('magnifyingglass', fallback: Icons.search),
            title: 'Search',
            group: 0,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
          NativeBarButton(
            icon: const NativeIcon.symbol('clock.badge.exclamationmark', fallback: Icons.timer_outlined),
            title: 'Expiring',
            group: 0,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ExpiringSubscriptionsScreen(),
                ),
              );
            },
          ),
          if (auth.hasTeamDataAccess)
            NativeBarButton(
              icon: const NativeIcon.symbol('arrow.left.arrow.right', fallback: Icons.swap_horiz),
              title: 'Scope',
              menu: [
                NativeMenuItem(
                  title: 'My Subscriptions',
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
                  title: 'Team Subscriptions',
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
            return Padding(
              padding: EdgeInsets.only(top: pad.top),
              child: Column(
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: LeadGlassSearchField(
                      placeholder: 'Search plan, customer, or order…',
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: LeadGlass.segmentBar(
                      context,
                      const ['All', 'Active', 'Expiring', 'Expired', 'Cancel'],
                      _statusIndex,
                      (i) {
                        setState(() {
                          _statusIndex = i;
                          _statusFilter = _statusKeys[i];
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading && _items.isEmpty
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
                          : PaginatedList(
                              items: displayedItems,
                              meta: _meta,
                              onLoadMore: _loadMore,
                              loadingMore: _loadingMore,
                              emptyTitle: _searchQuery.isNotEmpty
                                  ? 'No matching subscriptions'
                                  : 'No subscriptions found',
                              emptySubtitle: _searchQuery.isNotEmpty
                                  ? 'Try refining your search keyword.'
                                  : 'Customer subscriptions will appear here.',
                              tile: (context, s, i) {
                                final cs = Theme.of(context).colorScheme;
                                return NativeContextMenu(
                                  borderRadius: BorderRadius.circular(14),
                                  items: [
                                    NativeMenuItem(
                                      title: 'View Details',
                                      icon: const NativeIcon.symbol('arrow.right.circle', fallback: Icons.arrow_forward),
                                      onSelected: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SubscriptionDetailScreen(
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
                                    NativeMenuItem(
                                      title: 'Copy Details',
                                      icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                                      onSelected: () {
                                        final info = '${s.planSnapshot ?? 'Subscription #${s.id}'} - ${s.customerName ?? 'Customer'}';
                                        Clipboard.setData(ClipboardData(text: info));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Copied "$info" to clipboard')),
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
                                              backgroundColor: cs.primaryContainer
                                                  .withValues(alpha: 0.5),
                                              child: Icon(Icons.credit_card,
                                                  size: 16,
                                                  color: cs.onPrimaryContainer),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                s.planSnapshot ??
                                                    'Subscription #${s.id}',
                                                style: AppTypography.cardTitle
                                                    .copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: cs.onSurface),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            StatusBadge(status: s.status, compact: true),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                            '${s.customerName ?? 'Customer'} · ${s.orderNumber ?? 'Order #${s.orderId}'}',
                                            style: AppTypography.secondary.copyWith(
                                                color: cs.onSurface)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Expires ${Fmt.date(s.expiresAt)} · ${Fmt.relative(s.expiresAt)}',
                                          style: AppTypography.caption.copyWith(
                                              color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SubscriptionDetailScreen(
                                              subscriptionId: s.id),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
            ),
            ],
          ),
        );
      },
    ),
  ),
);
}
}

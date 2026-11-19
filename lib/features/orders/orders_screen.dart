import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/order.dart';
import '../../shared/models/subscription.dart' show ListMeta;
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../search/global_search_screen.dart';
import '../../core/utils/native_banner_helper.dart';
import 'order_create_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  ListMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _view = 'my_data';
  String _searchQuery = '';
  int _statusFilterIndex = 0;

  static const _statusFilters = ['all', 'pending', 'processing', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _orders.isEmpty;
      _error = null;
    });

    try {
      final res = await services.api.orders(view: _view, page: _page, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _orders = data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
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
          final res = await services.api.orders(view: 'my_data', page: _page, perPage: 20);
          final data = (res['data'] as List<dynamic>?) ?? const [];
          _orders = data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
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
      final res =
          await services.api.orders(view: _view, page: nextPage, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more = data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _orders.addAll(more);
        _page = nextPage;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _create() async {
    final services = context.read<AppServices>();
    final auth = context.read<AuthController>();
    if (!auth.canCreateOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to create orders')));
      return;
    }

    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderCreateScreen(services: services),
      ),
    );
    if (res == true && mounted) {
      _load();
    }
  }

  List<Order> get _filteredOrders {
    var list = _orders;
    final selectedFilter = _statusFilters[_statusFilterIndex];
    if (selectedFilter != 'all') {
      list = list.where((o) => o.orderStatus.toLowerCase() == selectedFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((o) =>
          o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          (o.customerPhone ?? '').contains(q) ||
          (o.customerEmail ?? '').toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canCreate = auth.canCreateOrders;
    final displayedOrders = _filteredOrders;

    final content = _loading && _orders.isEmpty
        ? const LoadingScreen()
        : RefreshIndicator(
            onRefresh: _load,
            child: _error != null && _orders.isEmpty
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
                      // ── Search & Filter header ───────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                        child: LeadGlassSearchField(
                          placeholder: 'Search invoice or customer…',
                          onChanged: (q) => setState(() => _searchQuery = q),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: LeadGlass.segmentBar(
                          context,
                          const ['All', 'Pending', 'Process', 'Done', 'Cancel'],
                          _statusFilterIndex,
                          (i) => setState(() => _statusFilterIndex = i),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: PaginatedList(
                          items: displayedOrders,
                          meta: _meta,
                          onLoadMore: _loadMore,
                          loadingMore: _loadingMore,
                          emptyTitle: _searchQuery.isNotEmpty ? 'No matches found' : 'No orders yet',
                          emptySubtitle: _searchQuery.isNotEmpty
                              ? 'Try refining your search keyword.'
                              : (canCreate
                                  ? 'Create your first order with the + button.'
                                  : 'Orders assigned to you will appear here.'),
                          tile: (context, o, i) => _OrderCard(
                            order: o,
                            isTeamView: _view == 'team_data',
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(orderId: o.id)));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          );

    return Scaffold(
      body: NativeNavigationBar(
        title: NativeBarTitle(
          title: 'Orders',
          subtitle: '${_orders.length} orders · ${_view == 'team_data' ? 'Team' : 'Mine'}',
          capsule: true,
          icon: const NativeIcon.symbol('cart.fill', fallback: Icons.shopping_bag),
        ),
        trailing: [
          if (canCreate)
            NativeBarButton(
              icon: const NativeIcon.symbol('plus', fallback: Icons.add),
              title: 'New',
              prominent: true,
              group: 1,
              onPressed: _create,
            ),
          NativeBarButton(
            icon: const NativeIcon.symbol('magnifyingglass', fallback: Icons.search),
            title: 'Search',
            group: 0,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
          if (auth.hasTeamDataAccess)
            NativeBarButton(
              icon: const NativeIcon.symbol('arrow.left.arrow.right', fallback: Icons.swap_horiz),
              title: 'Scope',
              group: 0,
              menu: [
                NativeMenuItem(
                  title: 'My Orders',
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
                  title: 'Team Orders',
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
        child: content,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    this.isTeamView = false,
  });

  final Order order;
  final VoidCallback onTap;
  final bool isTeamView;

  void _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NativeContextMenu(
      borderRadius: BorderRadius.circular(14),
      items: [
        NativeMenuItem(
          title: 'View Details',
          icon: const NativeIcon.symbol('arrow.right.circle', fallback: Icons.arrow_forward),
          onSelected: onTap,
        ),
        if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
          NativeMenuItem(
            title: 'Call Customer',
            icon: const NativeIcon.symbol('phone', fallback: Icons.phone),
            onSelected: () => _call(order.customerPhone!),
          ),
        NativeMenuItem(
          title: 'Copy Order Number',
          icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
          onSelected: () {
            Clipboard.setData(ClipboardData(text: order.orderNumber));
            showLeadxBanner(
              context,
              title: 'Copied to clipboard',
              body: order.orderNumber,
              icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
            );
          },
        ),
      ],
      child: AppCard.surface(
        context,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(14),
        radius: AppColors.radiusLg,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: cs.onSurface,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: order.orderStatus, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: AppTypography.cardTitle.copyWith(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                  InkWell(
                    onTap: () => _call(order.customerPhone!),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_outlined, size: 12, color: cs.primary),
                          const SizedBox(width: 3),
                          Text(
                            order.customerPhone!,
                            style: AppTypography.caption.copyWith(
                              color: cs.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (isTeamView &&
                (order.assignedEmployeeName != null ||
                    order.assignedEmployeeId != null)) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    order.assignedEmployeeName ??
                        'Employee #${order.assignedEmployeeId}',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    Fmt.money(order.closingValue),
                    style: AppTypography.statNumericSmall.copyWith(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: order.paymentStatus, compact: true),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined, size: 11, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    Fmt.date(order.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

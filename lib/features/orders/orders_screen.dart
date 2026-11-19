import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/app_typography.dart';
import '../../core/design/native_chrome.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../core/utils/native_banner_helper.dart';
import '../../shared/format.dart';
import '../../shared/models/order.dart';
import '../../shared/models/subscription.dart' show ListMeta;
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeleton_loading.dart';
import '../auth/auth_controller.dart';
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
  String _searchQuery = '';
  int _statusFilterIndex = 0;

  static const _filterTabs = [
    (filter: 'all', label: 'All'),
    (filter: 'pending', label: 'Pending'),
    (filter: 'processing', label: 'Processing'),
    (filter: 'completed', label: 'Completed'),
    (filter: 'cancelled', label: 'Cancelled'),
  ];

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
      final res = await services.api.orders(view: 'my_data', page: _page, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _orders = data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      _meta = ListMeta.fromJson((res['meta'] as Map<String, dynamic>?));
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } on ApiException catch (e) {
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
          await services.api.orders(view: 'my_data', page: nextPage, perPage: 20);
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
    final selectedFilter = _filterTabs[_statusFilterIndex].filter;
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
        ? const SkeletonListView(itemCount: 6, cardHeight: 110)
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
                      // ── Search Bar ───────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: _OrderSearchBar(
                          query: _searchQuery,
                          onChanged: (q) => setState(() => _searchQuery = q),
                        ),
                      ),
                      // ── Filter Chips ─────────────────────────────────────
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filterTabs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final tab = _filterTabs[i];
                            final isSelected = _statusFilterIndex == i;
                            final count = tab.filter == 'all'
                                ? _orders.length
                                : _orders.where((o) => o.orderStatus.toLowerCase() == tab.filter).length;
                            return _FilterChip(
                              label: tab.label,
                              count: count,
                              isSelected: isSelected,
                              onTap: () => setState(() => _statusFilterIndex = i),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── Orders List ──────────────────────────────────────
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
                                  ? 'Create your first order with the + button above.'
                                  : 'Orders assigned to you will appear here.'),
                          tile: (context, o, i) => _OrderCard(
                            order: o,
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
          subtitle: '${_orders.length} orders',
          capsule: false,
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
        ],
        child: content,
      ),
    );
  }
}

class _OrderSearchBar extends StatefulWidget {
  const _OrderSearchBar({
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_OrderSearchBar> createState() => _OrderSearchBarState();
}

class _OrderSearchBarState extends State<_OrderSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _OrderSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222226) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 19,
            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13.5,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search invoice or customer…',
                hintStyle: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                errorText: null,
                errorStyle: const TextStyle(fontSize: 0, height: 0),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onChanged('');
              },
              child: Icon(
                Icons.cancel,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final bg = isSelected
        ? (isDark ? Colors.white : const Color(0xFF171717))
        : (isDark ? const Color(0xFF26262B) : const Color(0xFFF1F5F9));
    final fg = isSelected
        ? (isDark ? const Color(0xFF171717) : Colors.white)
        : cs.onSurfaceVariant;
    final border = isSelected
        ? Border.all(color: isSelected ? bg : Colors.transparent)
        : Border.all(color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E8F0));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF171717).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25))
                      : (isDark ? const Color(0xFF38383E) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  final Order order;
  final VoidCallback onTap;

  void _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final customerInitial = order.customerName.trim().isNotEmpty
        ? order.customerName.trim()[0].toUpperCase()
        : 'C';

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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Order number & Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.receipt_outlined,
                              size: 13,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            order.orderNumber,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                              color: cs.onSurface,
                              fontFeatures: AppTypography.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Fmt.date(order.createdAt),
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: cs.onSurfaceVariant,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Middle Row: Customer Info & Call
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
                        ),
                        child: Center(
                          child: Text(
                            customerInitial,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                              order.customerName,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                color: cs.onSurface,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  order.customerPhone!,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone_outlined, size: 17),
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2A2A30) : const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(34, 34),
                          ),
                          onPressed: () => _call(order.customerPhone!),
                          tooltip: 'Call customer',
                        ),
                    ],
                  ),

                  // Optional Product snapshot
                  if ((order.productNameSnapshot ?? order.productName) != null &&
                      (order.productNameSnapshot ?? order.productName)!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF25252A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF33333A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '${order.productNameSnapshot ?? order.productName!} ${order.duration != null && order.duration!.isNotEmpty ? '• ${order.duration!}' : ''}'.trim(),
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Bottom Row: Price & Status Badges
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF27272C) : const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          Fmt.money(order.closingValue),
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            color: cs.onSurface,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            fontFeatures: AppTypography.tabularFigures,
                          ),
                        ),
                        const Spacer(),
                        StatusBadge(
                          status: order.paymentStatus,
                          compact: true,
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(
                          status: order.orderStatus,
                          compact: true,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

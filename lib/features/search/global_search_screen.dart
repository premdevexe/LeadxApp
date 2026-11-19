import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/services/app_services.dart';
import '../../core/utils/native_banner_helper.dart';
import '../../shared/format.dart';
import '../../shared/models/customer.dart';
import '../../shared/models/follow_up.dart';
import '../../shared/models/order.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/app_widgets.dart';
import '../customers/customer_detail_screen.dart';
import '../follow_ups/follow_up_detail_screen.dart';
import '../orders/order_detail_screen.dart';
import '../subscriptions/subscription_detail_screen.dart';

/// Full-fledged global search screen utilizing Veneer's **NativeSearchToolbar**:
/// An iOS 26 system search bar anchored at the bottom of the screen riding the keyboard,
/// with real-time omni-search across Orders, Customers, Tasks, and Subscriptions.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchKey = GlobalKey<NativeSearchToolbarState>();
  final _controller = TextEditingController();

  String _query = '';
  int _categoryIndex = 0; // 0: All, 1: Orders, 2: Customers, 3: Tasks, 4: Subs
  bool _loading = false;

  List<Order> _orders = [];
  List<Customer> _customers = [];
  List<FollowUp> _followUps = [];
  List<Subscription> _subscriptions = [];

  static const _categories = ['All', 'Orders', 'People', 'Tasks', 'Plans'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final services = context.read<AppServices>();

    try {
      final ordersRes = await services.api.orders(perPage: 30);
      final ordersData = (ordersRes['data'] as List<dynamic>?) ?? const [];
      _orders = ordersData.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    try {
      final custRes = await services.api.customers(perPage: 30);
      final custData = (custRes['data'] as List<dynamic>?) ?? const [];
      _customers = custData.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    try {
      final fuRes = await services.api.followUps(perPage: 30);
      final fuData = (fuRes['data'] as List<dynamic>?) ?? const [];
      _followUps = fuData.map((e) => FollowUp.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    try {
      final subRes = await services.api.subscriptions(perPage: 30);
      final subData = (subRes['data'] as List<dynamic>?) ?? const [];
      _subscriptions = subData.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _onQueryChanged(String val) {
    setState(() => _query = val.trim());
  }

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final q = _query.toLowerCase();

    final filteredOrders = _orders.where((o) =>
        o.orderNumber.toLowerCase().contains(q) ||
        o.customerName.toLowerCase().contains(q) ||
        (o.customerPhone ?? '').contains(q) ||
        (o.customerEmail ?? '').toLowerCase().contains(q)).toList();

    final filteredCustomers = _customers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.phone ?? '').contains(q) ||
        (c.email ?? '').toLowerCase().contains(q)).toList();

    final filteredTasks = _followUps.where((f) =>
        (f.title ?? '').toLowerCase().contains(q) ||
        (f.customerName ?? '').toLowerCase().contains(q) ||
        (f.description ?? '').toLowerCase().contains(q)).toList();

    final filteredSubs = _subscriptions.where((s) =>
        (s.planSnapshot ?? '').toLowerCase().contains(q) ||
        (s.customerName ?? '').toLowerCase().contains(q) ||
        (s.orderNumber ?? '').toLowerCase().contains(q)).toList();

    final totalMatches = filteredOrders.length +
        filteredCustomers.length +
        filteredTasks.length +
        filteredSubs.length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.neutralBgDark : AppColors.neutralBgLight,
      resizeToAvoidBottomInset: false,
      body: NativeSearchToolbar(
        key: _searchKey,
        placeholder: 'Search orders, customers, tasks, plans…',
        controller: _controller,
        autofocus: true,
        onChanged: _onQueryChanged,
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          children: [
            // ── Top header bar with safe-area spacing ─────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Search LeadX',
                      style: AppTypography.pageTitle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_query.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        ),
                        child: Text(
                          '$totalMatches results',
                          style: AppTypography.caption.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Category Filter Bar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LeadGlass.segmentBar(
                context,
                _categories,
                _categoryIndex,
                (i) => setState(() => _categoryIndex = i),
                height: 36,
              ),
            ),
            const SizedBox(height: 6),

            // ── Search Results List ──────────────────────────────────
            Expanded(
              child: _query.isEmpty
                  ? _buildQuickShortcuts(context)
                  : totalMatches == 0
                      ? const Center(
                          child: EmptyState(
                            title: 'No results found',
                            subtitle: 'Try a different keyword or invoice number.',
                            icon: Icons.search_off_rounded,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                          children: [
                            if ((_categoryIndex == 0 || _categoryIndex == 1) &&
                                filteredOrders.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Orders (${filteredOrders.length})',
                                icon: Icons.shopping_bag_outlined,
                              ),
                              for (final o in filteredOrders.take(10))
                                _SearchOrderTile(order: o, onCall: _callPhone),
                            ],
                            if ((_categoryIndex == 0 || _categoryIndex == 2) &&
                                filteredCustomers.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Customers (${filteredCustomers.length})',
                                icon: Icons.people_outline,
                              ),
                              for (final c in filteredCustomers.take(10))
                                _SearchCustomerTile(customer: c, onCall: _callPhone),
                            ],
                            if ((_categoryIndex == 0 || _categoryIndex == 3) &&
                                filteredTasks.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Tasks & follow-ups (${filteredTasks.length})',
                                icon: Icons.task_alt_outlined,
                              ),
                              for (final f in filteredTasks.take(10))
                                _SearchTaskTile(task: f),
                            ],
                            if ((_categoryIndex == 0 || _categoryIndex == 4) &&
                                filteredSubs.isNotEmpty) ...[
                              _SectionHeader(
                                title: 'Subscriptions (${filteredSubs.length})',
                                icon: Icons.repeat_outlined,
                              ),
                              for (final s in filteredSubs.take(10))
                                _SearchSubTile(sub: s),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickShortcuts(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Text(
          'Quick suggestions',
          style: AppTypography.caption.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SuggestionChip(
              icon: Icons.hourglass_top,
              label: 'Pending orders',
              onTap: () {
                _controller.text = 'pending';
                _onQueryChanged('pending');
              },
            ),
            _SuggestionChip(
              icon: Icons.check_circle_outline,
              label: 'Confirmed',
              onTap: () {
                _controller.text = 'confirmed';
                _onQueryChanged('confirmed');
              },
            ),
            _SuggestionChip(
              icon: Icons.timer_outlined,
              label: 'Expiring plans',
              onTap: () {
                _controller.text = 'active';
                _onQueryChanged('active');
              },
            ),
            _SuggestionChip(
              icon: Icons.phone_callback_outlined,
              label: 'Calls scheduled',
              onTap: () {
                _controller.text = 'call';
                _onQueryChanged('call');
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard.surface(
          context,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.keyboard_voice_outlined, size: 28, color: cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Native Dictation & Quick Ride',
                      style: AppTypography.cardTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap the microphone in the search bar below for instantaneous speech-to-text.',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchOrderTile extends StatelessWidget {
  const _SearchOrderTile({required this.order, required this.onCall});

  final Order order;
  final void Function(String) onCall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return NativeContextMenu(
      borderRadius: BorderRadius.circular(14),
      items: [
        NativeMenuItem(
          title: 'View Order',
          icon: const NativeIcon.symbol('cart', fallback: Icons.shopping_bag),
          onSelected: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
          ),
        ),
        if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
          NativeMenuItem(
            title: 'Call Customer',
            icon: const NativeIcon.symbol('phone', fallback: Icons.phone),
            onSelected: () => onCall(order.customerPhone!),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                StatusChip(order.orderStatus, compact: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.customerName,
              style: AppTypography.body.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  Fmt.money(order.closingValue),
                  style: AppTypography.statNumericSmall.copyWith(color: cs.onSurface),
                ),
                const Spacer(),
                Text(
                  Fmt.date(order.createdAt),
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCustomerTile extends StatelessWidget {
  const _SearchCustomerTile({required this.customer, required this.onCall});

  final Customer customer;
  final void Function(String) onCall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return NativeContextMenu(
      borderRadius: BorderRadius.circular(14),
      items: [
        NativeMenuItem(
          title: 'View Profile',
          icon: const NativeIcon.symbol('person.crop.circle', fallback: Icons.person),
          onSelected: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id)),
          ),
        ),
        if (customer.phone != null && customer.phone!.isNotEmpty)
          NativeMenuItem(
            title: 'Call Customer',
            icon: const NativeIcon.symbol('phone', fallback: Icons.phone),
            onSelected: () => onCall(customer.phone!),
          ),
      ],
      child: AppCard.surface(
        context,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: AppTypography.cardTitle.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                  Text(
                    [customer.phone, customer.email].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              Fmt.money(customer.totalPurchased),
              style: AppTypography.statNumericSmall.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTaskTile extends StatelessWidget {
  const _SearchTaskTile({required this.task});

  final FollowUp task;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return NativeContextMenu(
      borderRadius: BorderRadius.circular(14),
      items: [
        NativeMenuItem(
          title: 'View Details',
          icon: const NativeIcon.symbol('checklist', fallback: Icons.task_alt),
          onSelected: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FollowUpDetailScreen(followUpId: task.id)),
          ),
        ),
      ],
      child: AppCard.surface(
        context,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FollowUpDetailScreen(followUpId: task.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title ?? 'Task #${task.id}',
                    style: AppTypography.cardTitle.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                ),
                StatusChip(task.status, compact: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              task.customerName ?? 'Unassigned Client',
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSubTile extends StatelessWidget {
  const _SearchSubTile({required this.sub});

  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return NativeContextMenu(
      borderRadius: BorderRadius.circular(14),
      items: [
        NativeMenuItem(
          title: 'View Subscription',
          icon: const NativeIcon.symbol('repeat', fallback: Icons.repeat),
          onSelected: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(subscriptionId: sub.id)),
          ),
        ),
      ],
      child: AppCard.surface(
        context,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(subscriptionId: sub.id)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.planSnapshot ?? 'Subscription Plan',
                    style: AppTypography.cardTitle.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                  Text(
                    sub.customerName ?? '',
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusChip(sub.status, compact: true),
          ],
        ),
      ),
    );
  }
}

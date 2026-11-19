import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/customer.dart';
import '../../shared/models/subscription.dart' show ListMeta;
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';
import '../orders/order_create_sheet.dart';
import '../search/global_search_screen.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _items = [];
  ListMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _view = 'my_data';
  String _searchQuery = '';

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
      final res =
          await services.api.customers(view: _view, page: _page, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _items = data.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
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
          final res =
              await services.api.customers(view: 'my_data', page: _page, perPage: 20);
          final data = (res['data'] as List<dynamic>?) ?? const [];
          _items = data.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
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
          await services.api.customers(view: _view, page: nextPage, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more = data.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
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

  List<Customer> get _filteredCustomers {
    if (_searchQuery.trim().isEmpty) return _items;
    final q = _searchQuery.trim().toLowerCase();
    return _items.where((c) =>
      c.name.toLowerCase().contains(q) ||
      (c.phone ?? '').contains(q) ||
      (c.email ?? '').toLowerCase().contains(q)
    ).toList();
  }

  void _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _email(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final services = context.read<AppServices>();
    final displayed = _filteredCustomers;

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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: LeadGlassSearchField(
                          placeholder: 'Search customer name, phone, email…',
                          onChanged: (q) => setState(() => _searchQuery = q),
                        ),
                      ),
                      Expanded(
                        child: PaginatedList(
                          items: displayed,
                          meta: _meta,
                          onLoadMore: _loadMore,
                          loadingMore: _loadingMore,
                          emptyTitle: _searchQuery.isNotEmpty ? 'No matches' : 'No customers yet',
                          emptySubtitle: _searchQuery.isNotEmpty
                              ? 'Try refining your search keyword.'
                              : 'Customers appear here from orders you have completed.',
                          tile: (context, c, i) {
                            final cs = Theme.of(context).colorScheme;

                            return NativeContextMenu(
                              borderRadius: BorderRadius.circular(14),
                              items: [
                                NativeMenuItem(
                                  title: 'View Profile',
                                  icon: const NativeIcon.symbol('person.crop.circle', fallback: Icons.person),
                                  onSelected: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerDetailScreen(customerId: c.id),
                                      ),
                                    );
                                  },
                                ),
                                if (c.phone != null && c.phone!.isNotEmpty)
                                  NativeMenuItem(
                                    title: 'Call (${c.phone})',
                                    icon: const NativeIcon.symbol('phone', fallback: Icons.phone),
                                    onSelected: () => _call(c.phone!),
                                  ),
                                if (c.email != null && c.email!.isNotEmpty)
                                  NativeMenuItem(
                                    title: 'Email (${c.email})',
                                    icon: const NativeIcon.symbol('envelope', fallback: Icons.email),
                                    onSelected: () => _email(c.email!),
                                  ),
                                if (auth.canCreateOrders)
                                  NativeMenuItem(
                                    title: 'New Order for ${c.name}',
                                    icon: const NativeIcon.symbol('cart.badge.plus', fallback: Icons.add_shopping_cart),
                                    onSelected: () => showOrderCreateSheet(context, services),
                                  ),
                                NativeMenuItem(
                                  title: 'Copy Phone/Email',
                                  icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                                  onSelected: () {
                                    final contact = c.phone ?? c.email ?? c.name;
                                    Clipboard.setData(ClipboardData(text: contact));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Copied "$contact" to clipboard')),
                                    );
                                  },
                                ),
                              ],
                              child: AppCard.surface(
                                context,
                                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                        style: TextStyle(
                                          color: cs.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: AppTypography.cardTitle.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.phone ?? c.email ?? 'No contact info',
                                            style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${c.purchasesCount} order${c.purchasesCount == 1 ? '' : 's'} · ${Fmt.money(c.totalPurchased)}',
                                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    StatusBadge(status: c.status ?? '', compact: true),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CustomerDetailScreen(customerId: c.id),
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

    return Scaffold(
      body: NativeNavigationBar(
        title: NativeBarTitle(
          title: 'Customers',
          subtitle: '${_items.length} accounts · ${_view == 'team_data' ? 'Team' : 'Mine'}',
          capsule: true,
          icon: const NativeIcon.symbol('person.2.fill', fallback: Icons.people),
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
          if (auth.hasTeamDataAccess)
            NativeBarButton(
              icon: const NativeIcon.symbol('arrow.left.arrow.right', fallback: Icons.swap_horiz),
              title: 'Scope',
              menu: [
                NativeMenuItem(
                  title: 'My Customers',
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
                  title: 'Team Customers',
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

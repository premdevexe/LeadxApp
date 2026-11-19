import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/payment.dart';
import '../../shared/models/subscription.dart' show ListMeta;
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeleton_loading.dart';
import '../../core/utils/native_banner_helper.dart';
import '../auth/auth_controller.dart';
import '../search/global_search_screen.dart';
import 'payment_detail_screen.dart';

/// Page 4: `employee/payments` — Payment records under employee or team scope.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Payment> _items = [];
  ListMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _view = 'my_data';
  String _searchQuery = '';
  int _filterIndex = 0;

  List<Payment> get _filteredPayments {
    var list = _items;
    if (_filterIndex == 1) {
      list = list.where((p) => p.verified).toList();
    } else if (_filterIndex == 2) {
      list = list.where((p) => !p.verified).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((p) =>
        'payment #${p.id}'.contains(q) ||
        (p.transactionReference ?? '').toLowerCase().contains(q) ||
        (p.paymentMethod ?? '').toLowerCase().contains(q) ||
        '${p.orderId}'.contains(q)
      ).toList();
    }
    return list;
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
      final res =
          await services.api.payments(view: _view, page: _page, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _items = data.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
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
              await services.api.payments(view: 'my_data', page: _page, perPage: 20);
          final data = (res['data'] as List<dynamic>?) ?? const [];
          _items = data.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
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
          await services.api.payments(view: _view, page: nextPage, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more = data.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
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
    final canPop = Navigator.of(context).canPop();
    final displayed = _filteredPayments;

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: LeadGlassSearchField(
            placeholder: 'Search reference, method, or order…',
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: LeadGlass.segmentBar(
            context,
            const ['All', 'Verified', 'Pending'],
            _filterIndex,
            (i) => setState(() => _filterIndex = i),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading && _items.isEmpty
              ? const SkeletonListView(itemCount: 6, cardHeight: 100)
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
                          items: displayed,
                          meta: _meta,
                          onLoadMore: _loadMore,
                          loadingMore: _loadingMore,
                          emptyTitle: _searchQuery.isNotEmpty
                              ? 'No matching payments'
                              : 'No payments found',
                          emptySubtitle: _searchQuery.isNotEmpty
                              ? 'Try refining your search keyword.'
                              : 'Payments recorded from customer orders appear here.',
                          tile: (context, p, i) {
                      final cs = Theme.of(context).colorScheme;
                      final isDark = cs.brightness == Brightness.dark;
                      final accent = p.verified
                          ? StatusPalette.success(cs)
                          : StatusPalette.warning(cs);

                      return NativeContextMenu(
                        borderRadius: BorderRadius.circular(14),
                        items: [
                          NativeMenuItem(
                            title: 'View Details',
                            icon: const NativeIcon.symbol('arrow.right.circle', fallback: Icons.arrow_forward),
                            onSelected: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PaymentDetailScreen(paymentId: p.id),
                                ),
                              );
                            },
                          ),
                          NativeMenuItem(
                            title: 'Copy Reference ID',
                            icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                            onSelected: () {
                              final text = p.transactionReference ?? 'Payment #${p.id}';
                              Clipboard.setData(ClipboardData(text: text));
                              showLeadxBanner(
                                context,
                                title: 'Copied to clipboard',
                                body: text,
                                icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                              );
                            },
                          ),
                        ],
                        child: AppCard.surface(
                          context,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          padding: const EdgeInsets.all(14),
                          radius: AppColors.radiusLg,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PaymentDetailScreen(paymentId: p.id),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      p.verified
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.schedule_rounded,
                                      color: accent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Fmt.moneyFor(p.amount, code: p.currency),
                                          style: AppTypography.statNumericSmall.copyWith(
                                            color: cs.onSurface,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: AppTypography.tabularFigures,
                                          ),
                                        ),
                                        Text(
                                          p.orderNumber != null && p.orderNumber!.isNotEmpty
                                              ? p.orderNumber!
                                              : 'Order #${p.orderId}',
                                          style: TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: AppTypography.tabularFigures,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: p.paymentStatus, compact: true),
                                ],
                              ),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (p.paymentMethod ?? 'Unknown').toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.calendar_today_outlined, size: 11, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      Fmt.dateTime(p.paymentDate ?? p.createdAt),
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
                    },
                  ),
                ),
        ),
      ],
    );

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
          title: 'Payments',
          subtitle: '${_items.length} records',
          capsule: true,
          icon: const NativeIcon.symbol('creditcard.fill', fallback: Icons.payments),
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
            icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
            title: 'Refresh',
            group: 0,
            onPressed: _load,
          ),
          if (auth.hasTeamDataAccess)
            NativeBarButton(
              icon: const NativeIcon.symbol('arrow.left.arrow.right', fallback: Icons.swap_horiz),
              title: 'Scope',
              group: 0,
              menu: [
                NativeMenuItem(
                  title: 'My Payments',
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
                  title: 'Team Payments',
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

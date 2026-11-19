import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/follow_up.dart';
import '../../shared/models/subscription.dart' show ListMeta;
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeleton_loading.dart';
import '../../core/utils/native_banner_helper.dart';
import '../search/global_search_screen.dart';
import 'follow_up_create_sheet.dart';
import 'follow_up_detail_screen.dart';

/// Page 6: `employee/follow-ups` — Employee CRM follow-up activities
/// powered by **Veneer** native navigation and glass controls.
class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  List<FollowUp> _items = [];
  ListMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _statusIndex = 0;
  String _searchQuery = '';

  static const _statusKeys = ['pending', 'completed', 'rescheduled', 'cancelled', ''];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _currentStatus => _statusKeys[_statusIndex];

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });

    try {
      final res = await services.api.followUps(
        status: _currentStatus.isEmpty ? null : _currentStatus,
        page: _page,
        perPage: 20,
      );
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _items =
          data.map((e) => FollowUp.fromJson(e as Map<String, dynamic>)).toList();
      _meta = ListMeta.fromJson((res['meta'] as Map<String, dynamic>?));
      if (!mounted) return;
      setState(() => _loading = false);
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
      final res = await services.api.followUps(
        status: _currentStatus.isEmpty ? null : _currentStatus,
        page: nextPage,
        perPage: 20,
      );
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more =
          data.map((e) => FollowUp.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<void> _createNew() async {
    final created = await showFollowUpCreateSheet(context);
    if (created == true) {
      _load();
    }
  }

  IconData _iconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'call':
        return Icons.call_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'whatsapp':
        return Icons.chat_outlined;
      case 'meeting':
        return Icons.groups_outlined;
      default:
        return Icons.task_alt_outlined;
    }
  }

  List<FollowUp> get _displayedItems {
    if (_searchQuery.trim().isEmpty) return _items;
    final q = _searchQuery.trim().toLowerCase();
    return _items.where((f) =>
      (f.title ?? '').toLowerCase().contains(q) ||
      (f.customerName ?? '').toLowerCase().contains(q) ||
      (f.followUpType ?? '').toLowerCase().contains(q) ||
      (f.description ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _quickComplete(FollowUp f) async {
    final services = context.read<AppServices>();
    try {
      await services.api.updateFollowUp(f.id, {
        'status': 'completed',
        'outcome': 'Completed via LeadX fast action',
      });
      if (!mounted) return;
      showLeadxBanner(
        context,
        title: 'Task completed',
        body: 'Marked "${f.title ?? 'Task'}" as completed',
        icon: const NativeIcon.symbol('checkmark.circle.fill', fallback: Icons.check_circle),
      );
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayedItems;

    final content = _loading && _items.isEmpty
        ? const SkeletonListView(itemCount: 6, cardHeight: 110)
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
                      // ── Search & Filter header ───────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: LeadGlassSearchField(
                          placeholder: 'Search task title or customer…',
                          onChanged: (q) => setState(() => _searchQuery = q),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: LeadGlass.segmentBar(
                          context,
                          const ['Pending', 'Done', 'Resched', 'Cancel', 'All'],
                          _statusIndex,
                          (i) {
                            setState(() {
                              _statusIndex = i;
                              _page = 1;
                            });
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: PaginatedList(
                          items: displayed,
                          meta: _meta,
                          onLoadMore: _loadMore,
                          loadingMore: _loadingMore,
                          emptyTitle: _searchQuery.isNotEmpty
                              ? 'No matching tasks'
                              : 'No follow-ups found',
                          emptySubtitle:
                              'Schedule client follow-ups to keep opportunities moving.',
                          tile: (context, f, i) {
                            final cs = Theme.of(context).colorScheme;

                            return NativeContextMenu(
                              borderRadius: BorderRadius.circular(14),
                              items: [
                                NativeMenuItem(
                                  title: 'View Details',
                                  icon: const NativeIcon.symbol('arrow.right.circle', fallback: Icons.arrow_forward),
                                  onSelected: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FollowUpDetailScreen(followUpId: f.id),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                                if (f.status.toLowerCase() == 'pending')
                                  NativeMenuItem(
                                    title: 'Mark Completed',
                                    icon: const NativeIcon.symbol('checkmark.circle', fallback: Icons.check_circle_outline),
                                    onSelected: () => _quickComplete(f),
                                  ),
                              ],
                              child: AppCard.surface(
                                context,
                                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowUpDetailScreen(followUpId: f.id),
                                    ),
                                  );
                                  _load();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                                          child: Icon(
                                            _iconForType(f.followUpType),
                                            size: 16,
                                            color: cs.onPrimaryContainer,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            f.title ?? 'Follow-up #${f.id}',
                                            style: AppTypography.cardTitle.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: f.status, compact: true),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${f.customerName ?? 'Customer'} · ${f.followUpType?.toUpperCase() ?? 'CALL'}',
                                      style: AppTypography.secondary.copyWith(color: cs.onSurface),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          Fmt.dateTime(f.scheduledAt),
                                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                        if (f.calendarSyncStatus == 'synced') ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.event_available,
                                            size: 14,
                                            color: StatusPalette.success(cs),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
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
          title: 'Follow-ups',
          subtitle: '${_items.length} scheduled tasks',
          capsule: true,
          icon: const NativeIcon.symbol('checklist', fallback: Icons.task_alt),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('plus', fallback: Icons.add),
            title: 'Schedule',
            prominent: true,
            group: 1,
            onPressed: _createNew,
          ),
          NativeBarButton(
            icon: const NativeIcon.symbol('magnifyingglass', fallback: Icons.search),
            title: 'Search',
            group: 0,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
        ],
        child: content,
      ),
    );
  }
}

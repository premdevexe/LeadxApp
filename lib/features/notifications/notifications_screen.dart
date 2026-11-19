import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../core/realtime/reverb_service.dart';
import '../../shared/format.dart';
import '../../shared/models/notification.dart';
import '../../shared/widgets/app_widgets.dart';
import '../orders/order_detail_screen.dart';

/// Employee notifications (spec §4.9) with live updates.
///
/// Unread rows show a solid dot (a row is unread when its `read_at` is
/// null); the bar's unread figure comes from the list's
/// `meta.unread_count`. Tapping a row marks it read
/// (`POST /employee/notifications/{id}/read`) and deep-links to the
/// referenced order when the payload carries one. While the Reverb socket
/// is connected, `notification.received` frames trigger a refresh so fresh
/// rows appear without manual polling; when real-time is unavailable the
/// screen polls on an interval instead — the two never double-fire
/// because the socket path only emits while connected.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = const [];
  int _unread = 0;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _forbidden = false;

  Timer? _poll;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _load();
    _startPollingFallback();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Listen to the app's Reverb socket for `notification.received`. Re-called
  /// after the real-time connection comes up (login / reconnect), guarded by
  /// [_listening] so each live connection has exactly one listener.
  void _attachRealtime() {
    final services = Provider.of<AppServices>(context, listen: false);
    final reverb = services.reverb;
    if (reverb == null || _listening) return;
    _listening = true;
    reverb.addEventListener(_onRealtime);
  }

  void _onRealtime(RealtimeEvent e) {
    if (e.type == 'notification.received' && mounted) {
      _load(silent: true);
    }
  }

  /// While the socket is down, poll the notifications endpoint so the list
  /// still catches up. Cancelled (and the listener reattached) when the
  /// socket connects.
  void _startPollingFallback() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      // If real-time is up now, stop polling.
      if (context.read<AppServices>().reverb?.isConnected == true) {
        _poll?.cancel();
        _listening = false;
        _attachRealtime();
        return;
      }
      _load(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRealtime();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      // A user-initiated load (first load / pull-to-refresh) restarts from
      // the top; silent poll + real-time refreshes stay on the current page.
      _page = 1;
      _lastPage = 1;
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
        _forbidden = false;
      });
    }

    final services = context.read<AppServices>();
    try {
      final res = await services.api.notifications(page: _page, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      _items = data
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();

      final meta = (res['meta'] as Map<String, dynamic>?) ?? const {};
      _unread = (meta['unread_count'] as num?)?.toInt() ?? 0;
      _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _forbidden = e.isForbidden;
        _error = e.isNetwork ? 'No connection' : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _lastPage) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final services = context.read<AppServices>();
    try {
      final res = await services.api.notifications(
          page: nextPage, perPage: 20);
      final data = (res['data'] as List<dynamic>?) ?? const [];
      final more = data
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...more];
        _page = nextPage;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    final services = context.read<AppServices>();
    // Clear the dot + decrement the counter immediately; the next refresh
    // reconciles against the backend.
    setState(() {
      // Optimistic read: the backend's next response is authoritative.
      final nowIso = DateTime.now().toIso8601String();
      _items = [
        for (final item in _items)
          item.id == n.id ? AppNotification(
                id: item.id,
                type: item.type,
                data: item.data,
                readAt: nowIso,
                createdAt: item.createdAt,
              ) : item,
      ];
      if (_unread > 0) _unread -= 1;
    });
    try {
      await services.api.markNotificationRead(n.id);
      await _load(silent: true);
    } on ApiException {
      // Swallow: the next refresh recomputes the unread count.
    }
  }

  Future<void> _markAll() async {
    final services = context.read<AppServices>();
    try {
      await services.api.markAllNotificationsRead();
      await _load(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All notifications read')));
      }
    } on ApiException {
      if (!mounted) return;
    }
  }

  void _open(AppNotification n) {
    _markRead(n);
    // Deep-link to the referenced order when the payload carries one.
    final orderId = n.orderId;
    if (orderId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    Widget content;
    if (_loading && _items.isEmpty) {
      content = const LoadingScreen();
    } else if (_forbidden && _items.isEmpty) {
      // 403: not a crash — a plain not-allowed card.
      content = Center(
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
                  "You don't have access to notifications",
                  textAlign: TextAlign.center,
                  style: AppTypography.cardTitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact your manager to request access.',
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary.copyWith(
                      color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (_error != null && _items.isEmpty)
              ErrorBanner(message: _error!, onRetry: _load),
            if (_items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications',
                subtitle: 'Order, payment and renewal updates will appear here.',
              )
            else ...[
              ..._items.map((n) => _NotificationRow(n: n, onOpen: () => _open(n))),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()))
              else if (_page < _lastPage)
                Center(
                  child: TextButton(
                    onPressed: _loadMore,
                    child: const Text('Load more')),
                ),
            ],
          ],
        ),
      );
    }

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
          title: 'Notifications',
          subtitle: _unread > 0 ? '$_unread unread' : 'All caught up',
          capsule: true,
          icon: const NativeIcon.symbol('bell.fill', fallback: Icons.notifications),
        ),
        trailing: [
          if (_unread > 0 && !_forbidden)
            NativeBarButton(
              icon: const NativeIcon.symbol('checkmark.circle', fallback: Icons.done_all_outlined),
              title: 'Mark all read',
              onPressed: _markAll,
            ),
        ],
        child: Builder(
          builder: (context) {
            final pad = MediaQuery.paddingOf(context);
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

/// One dense notification row: fixed 48px height, 14px title / 12px
/// secondary, an 8px unread dot when `read_at` is null. Flat and
/// neutral — no tinted surfaces, no gradients.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.n, required this.onOpen});

  final AppNotification n;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = !n.isRead;
    final time = n.createdAt != null ? Fmt.dateTime(n.createdAt!) : '';

    return AppCard.surface(
      context,
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 48,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Unread = solid dot; read = faint ring. Both read off the
                // active ColorScheme so they stay visible in light and dark.
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unread ? cs.onSurface : cs.outlineVariant,
                    border: !unread
                        ? Border.all(color: cs.outlineVariant, width: 1.5)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle.copyWith(
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      if (n.message.isNotEmpty)
                        Text(
                          n.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.secondary.copyWith(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

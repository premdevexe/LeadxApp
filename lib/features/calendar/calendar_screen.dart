import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/native_chrome.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/calendar_event.dart';
import '../../shared/models/google_calendar.dart';
import '../../shared/widgets/app_widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarStatus? _status;
  bool _loading = true;
  String? _error;

  // Google Calendar OAuth integration (spec §10) — separate from the local
  // events module above.
  GoogleCalendarStatus? _google;
  bool _googleBusy = false;
  String? _googleError;

  final _summary = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _start;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadGoogle();
  }

  /// Loads the Google Calendar OAuth connection status (spec §10).
  ///
  /// A 403 (team shared login) means the integration is not allowed for
  /// this account — the card falls back to a neutral not-connected state
  /// with the backend's message rather than an error screen.
  Future<void> _loadGoogle() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.calendarStatus();
      if (!mounted) return;
      setState(() {
        _google = GoogleCalendarStatus.fromJson(res);
        _googleError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _google = const GoogleCalendarStatus(connected: false);
        _googleError = e.statusCode == 403
            ? 'Not allowed for this account: ${e.message}'
            : null;
      });
    }
  }

  /// Disconnect flow: confirm dialog → revoke → reload status → snackbar.
  Future<void> _disconnect() async {
    final confirmed = await _confirmDisconnect();
    if (!confirmed || !mounted) return;

    setState(() => _googleBusy = true);
    final services = context.read<AppServices>();
    try {
      await services.api.calendarDisconnect();
      await _loadGoogle();
      if (!mounted) return;
      setState(() => _googleBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar disconnected')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _googleBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          e.statusCode == 403
              ? 'Not allowed for this account.'
              : e.statusCode == 503
                  ? 'Calendar not configured on this server'
                  : e.message)));
    }
  }

  /// Destructive confirm dialog with ≥44×44 action buttons.
  Future<bool> _confirmDisconnect() async {
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusLg)),
        title: const Text('Disconnect Google Calendar?'),
        content: const Text('Events will stop syncing.'),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              style: ButtonStyle(
                  foregroundColor:
                      WidgetStatePropertyAll(StatusPalette.danger(cs))),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Disconnect',
                  style: AppTypography.labelLarge.copyWith(
                      color: StatusPalette.danger(cs),
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = _status == null;
      _error = null;
    });
    try {
      final res = await services.api.calendar();
      if (!mounted) return;
      setState(() {
        _status = CalendarStatus.fromJson(res);
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

  Future<void> _pickTimes() async {
    final now = DateTime.now();
    final start = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now.add(const Duration(days: 365 * 2)));
    if (!mounted || start == null) return;

    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    setState(() {
      _start = DateTime(start.year, start.month, start.day, time.hour, time.minute);
    });
  }

  Future<void> _create() async {
    if (_summary.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary is required')));
      return;
    }
    if (_start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a start time')));
      return;
    }

    setState(() => _busy = true);
    final services = context.read<AppServices>();
    try {
      final payload = <String, dynamic>{
        'summary': _summary.text.trim(),
        'start_at': _start!.toIso8601String(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      };
      await services.api.createCalendarEvent(payload);
      _summary.clear();
      _desc.clear();
      _start = null;
      if (mounted) setState(() => _busy = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sync() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.syncCalendar();
      await _load();
      if (!mounted) return;
      final meta = (res['meta'] as Map<String, dynamic>?) ?? {};
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Synced ${meta['events_synced'] ?? 0} event(s)${meta['failed'] != null && (meta['failed'] as num).toInt() > 0 ? ', ${meta['failed']} failed' : ''}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _connect() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.calendarConnectUrl();
      final url = res['url'] as String?;
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.statusCode == 503 ? 'Calendar not configured on this server' : e.message)));
    }
  }

  Future<void> _remove(CalendarEvent e) async {
    final services = context.read<AppServices>();
    try {
      await services.api.deleteCalendarEvent(e.id);
      await _load();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  void dispose() {
    _summary.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    final connected = _status?.connection.connected ?? false;

    if (_loading && _status == null) {
      return Scaffold(
        body: NativeNavigationBar(
          leading: canPop
              ? NativeBarButton(
                  icon: const NativeIcon.symbol('chevron.left', fallback: Icons.arrow_back),
                  title: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: const NativeBarTitle(
            title: 'Calendar & Sync',
            capsule: true,
            icon: NativeIcon.symbol('calendar', fallback: Icons.calendar_month),
          ),
          child: const LoadingScreen(),
        ),
      );
    }

    if (_error != null && _status == null) {
      return Scaffold(
        body: NativeNavigationBar(
          leading: canPop
              ? NativeBarButton(
                  icon: const NativeIcon.symbol('chevron.left', fallback: Icons.arrow_back),
                  title: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: const NativeBarTitle(
            title: 'Calendar & Sync',
            capsule: true,
            icon: NativeIcon.symbol('calendar', fallback: Icons.calendar_month),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(message: _error!, onRetry: _load),
            ),
          ),
        ),
      );
    }

    final events = _status?.events ?? const <CalendarEvent>[];

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
          title: 'Calendar & Sync',
          subtitle: connected ? 'Connected · ${events.length} events' : 'Disconnected',
          capsule: true,
          icon: const NativeIcon.symbol('calendar', fallback: Icons.calendar_month),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('arrow.triangle.2.circlepath', fallback: Icons.sync),
            title: 'Sync',
            onPressed: _sync,
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            await _load();
            await _loadGoogle();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
                  // 36-Hour Advance Expiry Notification Banner (mirrors calendar.blade.php)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // blue-50
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE), // blue-200
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB), // blue-600
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          ),
                          child: const Icon(Icons.schedule, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '36-Hour Advance Expiry Notification Configured',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A), // blue-900
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'LeadX synchronizes subscription expiration reminders directly to your Google Calendar with a mandatory 36-hour lead time (2,160 minutes before expiration). You will receive both a popup alarm and an email notification 36 hours prior to any customer subscription ending.',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF), // blue-800
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Google Calendar OAuth integration (spec §10) — personal
                  // Google account, distinct from the local events module below.
                  _buildGoogleCalendarCard(context, cs),
              const SizedBox(height: 12),
              // Connection banner.
              AppCard.surface(
                context,
                padding: const EdgeInsets.all(12),
                color: connected
                    ? cs.primaryContainer.withValues(alpha: 0.5)
                    : cs.errorContainer.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Icon(
                      connected ? Icons.cloud_done : Icons.cloud_off,
                      size: 20,
                      color: connected
                          ? StatusPalette.success(cs)
                          : StatusPalette.danger(cs),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connected
                            ? 'Google Calendar connected'
                            : 'Google Calendar not connected',
                        style: AppTypography.body.copyWith(
                            color: connected
                                ? StatusPalette.success(cs)
                                : StatusPalette.danger(cs)),
                      ),
                    ),
                    if (!connected)
                      TextButton(
                          onPressed: _connect,
                          child: Text('Connect',
                              style: AppTypography.secondary.copyWith(
                                  color: StatusPalette.danger(cs),
                                  fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Create form.
              AppCard.surface(
                context,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _summary,
                            decoration: const InputDecoration(
                                hintText: 'New event summary',
                                border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickTimes,
                          icon: Icon(
                              _start == null
                                  ? Icons.schedule
                                  : Icons.check_circle,
                              size: 16),
                          label: Text(_start == null
                              ? 'Time'
                              : DateFormat('EEE d MMM h:mm a')
                                  .format(_start!)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                            onPressed: _busy ? null : _create,
                            child: const Text('Add')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _desc,
                      decoration: const InputDecoration(
                          hintText: 'Notes (optional)',
                          border: OutlineInputBorder()),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard.section(context, 'Events'),
              if (events.isEmpty)
                const EmptyState(
                  title: 'No calendar events',
                  subtitle:
                      'Events are stored locally and synced to Google when connected.',
                  icon: Icons.calendar_month_outlined,
                )
              else
                for (final e in events)
                  _buildEventCard(context, e, cs),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Spec §10: personal Google Calendar OAuth card — connection status,
  /// connect (external-browser OAuth) or disconnect (confirmed, destructive).
  Widget _buildGoogleCalendarCard(BuildContext context, ColorScheme cs) {
    final g = _google;
    final connected = g?.connected ?? false;
    final email = g?.effective.googleEmail;
    final danger = StatusPalette.danger(cs);

    return AppCard.surface(
      context,
      radius: AppColors.radiusLg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: connected
                      ? StatusPalette.success(cs).withValues(alpha: 0.14)
                      : cs.onSurfaceVariant.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Icon(
                  connected ? Icons.cloud_done : Icons.cloud_off,
                  size: 18,
                  color: connected
                      ? StatusPalette.success(cs)
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Calendar',
                        style: AppTypography.cardTitle.copyWith(
                            fontWeight: FontWeight.w600, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      g == null
                          ? 'Checking connection…'
                          : connected
                              ? (email != null
                                  ? 'Connected as $email'
                                  : 'Connected')
                              : 'Not connected',
                      style: AppTypography.secondary.copyWith(
                          color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_googleError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _googleError!,
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 10),
          connected
              ? SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: danger),
                      foregroundColor: danger,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusMd)),
                    ),
                    onPressed: _googleBusy ? null : _disconnect,
                    child: _googleBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Disconnect',
                            style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w600)),
                  ),
                )
              : SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusMd)),
                    ),
                    onPressed: _connect,
                    child: const Text('Connect'),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, CalendarEvent e, ColorScheme cs) {
    final start = DateTime.tryParse(e.startAt ?? '');
    final statusColor = e.status == 'synced'
        ? StatusPalette.success(cs)
        : e.status == 'error'
            ? StatusPalette.danger(cs)
            : cs.onSurfaceVariant;
    return AppCard.surface(
      context,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              e.status == 'error'
                  ? Icons.sync_problem
                  : Icons.calendar_month,
              size: 18,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.summary,
                    style: AppTypography.cardTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  start != null
                      ? '${DateFormat('EEE d MMM, h:mm a').format(start)} · ${Fmt.relative(e.startAt)}'
                      : Fmt.relative(e.startAt),
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: StatusPalette.danger(cs)),
            tooltip: 'Delete event',
            onPressed: () => _remove(e),
          ),
        ],
      ),
    );
  }
}

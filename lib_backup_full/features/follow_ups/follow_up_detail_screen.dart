import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../shared/format.dart';
import '../../shared/models/follow_up.dart';
import '../../shared/widgets/app_widgets.dart';
import '../customers/customer_detail_screen.dart';

/// Screen 6 Detail: `GET /employee/follow-ups/{id}` + Reschedule, Complete, Cancel
class FollowUpDetailScreen extends StatefulWidget {
  const FollowUpDetailScreen({super.key, required this.followUpId});

  final int followUpId;

  @override
  State<FollowUpDetailScreen> createState() => _FollowUpDetailScreenState();
}

class _FollowUpDetailScreenState extends State<FollowUpDetailScreen> {
  FollowUp? _followUp;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = context.read<AppServices>();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await services.api.followUpDetail(widget.followUpId);
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      _followUp = FollowUp.fromJson(data);
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

  Future<void> _actionReschedule() async {
    DateTime pickedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay pickedTime = const TimeOfDay(hour: 10, minute: 0);
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Reschedule Follow-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('New Date & Time'),
                subtitle: Text(
                  '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')} at ${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    if (!ctx.mounted) return;
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: pickedTime,
                    );
                    if (t != null) {
                      setDlgState(() {
                        pickedDate = d;
                        pickedTime = t;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason / Notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ).toIso8601String();

      final req = FollowUpActionRequest.reschedule(
        scheduledAt: scheduledAt,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      final services = context.read<AppServices>();
      try {
        await services.api.updateFollowUp(widget.followUpId, req.toJson());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up rescheduled successfully')),
        );
        _load();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _actionComplete() async {
    final outcomeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: outcomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Outcome (e.g. Renewed, Closed, Interested)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final req = FollowUpActionRequest.complete(
        outcome: outcomeCtrl.text.trim().isNotEmpty ? outcomeCtrl.text.trim() : 'Completed',
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      final services = context.read<AppServices>();
      try {
        await services.api.updateFollowUp(widget.followUpId, req.toJson());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up marked as completed')),
        );
        _load();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _actionCancel() async {
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this follow-up? (LeadX maintains cancellation history).'),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: StatusPalette.danger(Theme.of(ctx).colorScheme)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Follow-up'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final req = FollowUpActionRequest.cancel(
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      final services = context.read<AppServices>();
      try {
        await services.api.updateFollowUp(widget.followUpId, req.toJson());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up cancelled')),
        );
        _load();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    if (_loading && _followUp == null) {
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
            title: 'Follow-up Details',
            capsule: true,
            icon: NativeIcon.symbol('checklist', fallback: Icons.task_alt),
          ),
          child: const LoadingScreen(),
        ),
      );
    }

    if (_error != null && _followUp == null) {
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
            title: 'Follow-up Details',
            capsule: true,
            icon: NativeIcon.symbol('checklist', fallback: Icons.task_alt),
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

    final f = _followUp!;
    final isPending = f.status.toLowerCase() == 'pending';

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
          title: f.title ?? 'Follow-up #${f.id}',
          subtitle: '${f.customerName ?? 'Client'} · ${f.status}',
          capsule: true,
          icon: const NativeIcon.symbol('checklist', fallback: Icons.task_alt),
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
            title: 'Refresh',
            group: 0,
            onPressed: _load,
          ),
          if (isPending)
            NativeBarButton(
              icon: const NativeIcon.symbol('checkmark.circle', fallback: Icons.check_circle_outline),
              title: 'Complete',
              prominent: true,
              group: 1,
              onPressed: _actionComplete,
            ),
        ],
        child: Builder(
          builder: (context) {
            final pad = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, pad.bottom + 24),
                children: [
            AppCard.surface(
              context,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.task_alt,
                            size: 18, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.title ?? 'Follow-up #${f.id}',
                              style: AppTypography.pageTitle.copyWith(
                                  fontSize: 18, color: cs.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusChip(f.status, compact: true),
                                if (f.priority != null && f.priority!.isNotEmpty)
                                  StatusChip(f.priority!, compact: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (f.description != null && f.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(f.description!,
                        style:
                            AppTypography.body.copyWith(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  _row(context, 'Type', (f.followUpType ?? 'call').toUpperCase()),
                  _row(context, 'Scheduled At', Fmt.dateTime(f.scheduledAt)),
                  if (f.completedAt != null)
                    _row(context, 'Completed At', Fmt.dateTime(f.completedAt)),
                  if (f.outcome != null) _row(context, 'Outcome', f.outcome!),
                  if (f.calendarSyncStatus != null)
                    _row(
                      context,
                      'Calendar Sync',
                      f.calendarSyncStatus == 'synced'
                          ? 'Synced with Google Calendar'
                          : f.calendarSyncStatus!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (f.customerId != null && f.customerId! > 0)
              AppCard.surface(
                context,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Customer', style: AppTypography.cardTitle),
                  subtitle: Text(
                      f.customerName ?? 'Customer #${f.customerId}',
                      style:
                          AppTypography.secondary.copyWith(color: cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerDetailScreen(customerId: f.customerId!),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            if (isPending) ...[
              AppCard.section(context, 'Actions', top: 0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Reschedule'),
                      onPressed: _actionReschedule,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Complete'),
                      onPressed: _actionComplete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: Icon(Icons.cancel_outlined,
                      size: 18, color: StatusPalette.danger(cs)),
                  label: Text('Cancel Follow-up',
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: StatusPalette.danger(cs))),
                  onPressed: _actionCancel,
                ),
              ),
            ],
          ],
        ),
      );
    },
  ),
),
);
}

  Widget _row(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: AppTypography.secondary.copyWith(
                    color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w500, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

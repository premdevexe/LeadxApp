import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/lead_glass.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_services.dart';
import '../../core/design/theme_controller.dart';

/// Opens the "Schedule follow-up" form.
///
/// With the "Liquid Glass" preference on it presents in a native
/// [showNativeSheet] (real UIKit sheet on iOS 26+; a Flutter replica
/// elsewhere); with it off the standard Material bottom sheet is used.
/// The form's fields and call to action are kit Liquid Glass surfaces that
/// follow the same toggle.
Future<bool?> showFollowUpCreateSheet(
  BuildContext context, {
  int? preselectedCustomerId,
}) {
  final useGlass = context.read<ThemeController>().glassEnabled;
  if (useGlass) {
    return showNativeSheet<bool>(
      context: context,
      detents: const [
        NativeSheetDetent.fraction(0.65),
        NativeSheetDetent.large,
      ],
      initialDetent: const NativeSheetDetent.fraction(0.65),
      showGrabber: true,
      builder: (_) =>
          FollowUpCreateSheet(preselectedCustomerId: preselectedCustomerId),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        FollowUpCreateSheet(preselectedCustomerId: preselectedCustomerId),
  );
}

class FollowUpCreateSheet extends StatefulWidget {
  const FollowUpCreateSheet({super.key, this.preselectedCustomerId});

  final int? preselectedCustomerId;

  @override
  State<FollowUpCreateSheet> createState() => _FollowUpCreateSheetState();
}

class _FollowUpCreateSheetState extends State<FollowUpCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _customerId;
  List<Map<String, dynamic>> _customers = [];
  bool _loadingCustomers = true;

  String _type = 'call';
  String _priority = 'medium';
  DateTime? _scheduledAt;
  bool _syncToCalendar = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _customerId = widget.preselectedCustomerId;
    _scheduledAt = DateTime.now().add(const Duration(hours: 2));
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final services = context.read<AppServices>();
    try {
      final res = await services.api.verifiedCustomers();
      final data = (res['data'] as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _customers = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingCustomers = false;
        if (_customerId == null && _customers.isNotEmpty) {
          _customerId = (_customers.first['id'] as num?)?.toInt();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (!mounted || time == null) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select scheduled date and time')),
      );
      return;
    }

    setState(() => _submitting = true);
    final services = context.read<AppServices>();

    try {
      final payload = {
        'customer_id': _customerId,
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'follow_up_type': _type,
        'priority': _priority,
        'scheduled_at': _scheduledAt!.toIso8601String(),
        'sync_to_calendar': _syncToCalendar,
      };

      await services.api.createFollowUp(payload);
      if (!mounted) return;
      // Works for both the native (iOS 26+) sheet and the Flutter fallback.
      await NativeSheet.close(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Schedule Follow-up',
                    style: AppTypography.sectionTitle
                        .copyWith(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => NativeSheet.close(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadingCustomers)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                )
              else if (_customers.isEmpty)
                Text(
                  'No verified customers available to schedule follow-ups with.',
                  style: AppTypography.secondary.copyWith(
                      color: StatusPalette.danger(Theme.of(context).colorScheme)),
                )
              else
                LeadGlass.field(
                  context,
                  DropdownButtonFormField<int>(
                    initialValue: _customerId,
                    decoration: LeadGlass.fieldDecoration(
                        context, label: 'Customer *'),
                    items: _customers.map((c) {
                      final id = (c['id'] as num).toInt();
                      final name = c['name'] as String? ?? 'Customer #$id';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _customerId = val),
                    validator: (v) => v == null ? 'Customer required' : null,
                  ),
                ),
              const SizedBox(height: 12),
              LeadGlass.field(
                context,
                TextFormField(
                  controller: _titleCtrl,
                  decoration: LeadGlass.fieldDecoration(
                    context,
                    label: 'Title *',
                    hint: 'e.g. Renewal check-in / Demo follow-up',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title required' : null,
                ),
              ),
              const SizedBox(height: 12),
              LeadGlass.field(
                context,
                TextFormField(
                  controller: _descCtrl,
                  decoration: LeadGlass.fieldDecoration(
                      context, label: 'Description / Notes'),
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LeadGlass.field(
                      context,
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration:
                            LeadGlass.fieldDecoration(context, label: 'Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'call', child: Text('Phone Call')),
                          DropdownMenuItem(value: 'email',
                              child: Text('Email')),
                          DropdownMenuItem(
                              value: 'whatsapp', child: Text('WhatsApp')),
                          DropdownMenuItem(
                              value: 'meeting', child: Text('Meeting')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _type = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LeadGlass.field(
                      context,
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: LeadGlass.fieldDecoration(
                            context, label: 'Priority'),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                              value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(
                              value: 'high', child: Text('High')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event,
                    color: Theme.of(context).colorScheme.primary),
                title: Text('Scheduled Time *',
                    style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                  _scheduledAt != null
                      ? '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} at ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}'
                      : 'Tap to select',
                  style: AppTypography.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickDateTime,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sync to Google Calendar',
                    style: AppTypography.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Creates event if Google Calendar is connected',
                    style:
                        AppTypography.secondary.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                value: _syncToCalendar,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (v) => setState(() => _syncToCalendar = v),
              ),
              const SizedBox(height: 16),
              LeadGlass.button(
                context,
                const Text('Schedule Follow-up'),
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
                primary: true,
                radius: 14,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/native_chrome.dart';

import '../../core/constants/app_constants.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/app_services.dart';
import '../../core/design/theme_controller.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';

/// Profile: identity view, contact-field edits, password change,
/// appearance preferences, and logout. Role/team/permissions are
/// admin-managed and can never be sent (the backend rejects them).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _curPass = TextEditingController();
  final _newPass = TextEditingController();
  final _confPass = TextEditingController();

  bool _saving = false;
  bool _changingPassword = false;
  String? _msg;
  String _msgType = 'ok';

  @override
  void initState() {
    super.initState();
    _seed();
  }

  void _seed() {
    final auth = context.read<AuthController>();
    _nameCtrl.text = auth.me?.data.name ?? '';
    _phoneCtrl.text = auth.me?.data.phone ?? '';
    _emailCtrl.text = auth.me?.data.email ?? '';
  }

  Future<void> _saveContact() async {
    setState(() {
      _saving = true;
      _msg = null;
    });

    final payload = <String, dynamic>{
      if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty)
        'email': _emailCtrl.text.trim(),
    };

    if (payload.length < 2) {
      setState(() {
        _saving = false;
        _msg = 'Nothing to update.';
        _msgType = 'warn';
      });
      return;
    }

    final services = context.read<AppServices>();
    try {
      await services.api.updateProfile(payload);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _msg = 'Profile updated.';
        _msgType = 'ok';
      });
      context.read<AuthController>().refreshMe();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _msg = e.isValidation
            ? (e.fieldErrors.values.isNotEmpty
                ? e.fieldErrors.values.first.first
                : 'Validation failed')
            : e.message;
        _msgType = 'err';
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPass.text.length < 8 ||
        !RegExp(r'[a-zA-Z]').hasMatch(_newPass.text) ||
        !RegExp(r'[0-9]').hasMatch(_newPass.text)) {
      setState(() {
        _msg = 'New password needs 8+ chars with letters and numbers.';
        _msgType = 'warn';
      });
      return;
    }
    if (_newPass.text != _confPass.text) {
      setState(() {
        _msg = 'Passwords do not match.';
        _msgType = 'warn';
      });
      return;
    }

    setState(() {
      _changingPassword = true;
      _msg = null;
    });

    final services = context.read<AppServices>();
    try {
      await services.api.updateProfile({
        'current_password': _curPass.text,
        'password': _newPass.text,
        'password_confirmation': _confPass.text,
      });
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _msg =
            'Password changed. Other devices of this account were signed out.';
        _msgType = 'ok';
      });
      _curPass.clear();
      _newPass.clear();
      _confPass.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _msg = e.isValidation
            ? 'Password change rejected (check current password).'
            : e.message;
        _msgType = 'err';
      });
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final confirmed = await showNativeAlert(
      context: context,
      title: 'Sign out of LeadX?',
      message: 'Revoking this device session on the backend. You will need to sign in again.',
      tint: Theme.of(context).colorScheme.error,
      actions: const [
        NativeAlertAction(title: 'Cancel', style: NativeAlertActionStyle.cancel),
        NativeAlertAction(
          title: 'Sign Out',
          style: NativeAlertActionStyle.destructive,
          preferred: true,
        ),
      ],
    );
    if (confirmed == 1 && mounted) {
      await context.read<AuthController>().logout();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _curPass.dispose();
    _newPass.dispose();
    _confPass.dispose();
    super.dispose();
  }

  Widget _systemRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final emp = auth.me?.data;
    final canPop = Navigator.of(context).canPop();

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
          title: 'Profile & Settings',
          capsule: true,
          icon: NativeIcon.symbol('person.crop.circle', fallback: Icons.account_circle),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
          if (emp != null) ...[
            // Profile Card matching profile.blade.php
            AppCard.surface(
              context,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF171717),
                    ),
                    child: Center(
                      child: Text(
                        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emp.name,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (emp.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      emp.email!,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF262626)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF383838)
                                : const Color(0xFFE5E5E5),
                          ),
                        ),
                        child: Text(
                          '@${emp.username}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        status: '${emp.status ?? 'active'} Account',
                        type: (emp.status ?? 'active') == 'active'
                            ? 'success'
                            : 'danger',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // System-Assigned Info (Read-Only)
                  _systemRow(context, 'Employee ID', '#${emp.id}'),
                  _systemRow(context, 'System Role',
                      (emp.role ?? 'Employee').toUpperCase()),
                  _systemRow(context, 'Assigned Team',
                      emp.team?.teamName ?? 'None'),
                  _systemRow(context, 'Team Code',
                      emp.team?.teamCode ?? '—'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Team assignment and role permissions are managed exclusively by Super Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_msg != null)
            AppCard.surface(
              context,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              color: _msgType == 'err'
                  ? cs.errorContainer
                  : _msgType == 'warn'
                      ? cs.tertiaryContainer
                      : cs.primaryContainer,
              child: Text(
                _msg!,
                style: AppTypography.secondary.copyWith(
                    color: _msgType == 'err'
                        ? cs.onErrorContainer
                        : _msgType == 'warn'
                            ? cs.onTertiaryContainer
                            : cs.onPrimaryContainer),
              ),
            ),
          // ── Contact details ───────────────────────────────────────
          AppCard.surface(
            context,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('CONTACT DETAILS',
                    style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 12),
                TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 10),
                TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 10),
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _saving ? null : _saveContact,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Appearance & preferences ──────────────────────────────
          AppCard.surface(
            context,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance & preferences',
                    style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _AppearanceRow(),
                const Divider(height: 24),
                // Live admin currency — a read-only mirror of the Admin
                // panel; it updates on the next dashboard refresh.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Display currency',
                              style: AppTypography.body.copyWith(
                                  color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            _currencyLine(context),
                            style:
                                AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.currency_exchange, size: 20, color: cs.primary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Change password ───────────────────────────────────────
          AppCard.surface(
            context,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Change password',
                    style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Changing the password signs out this account on all '
                  'other devices.',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: _curPass,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Current password')),
                const SizedBox(height: 10),
                TextField(
                    controller: _newPass,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'New password')),
                const SizedBox(height: 10),
                TextField(
                    controller: _confPass,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Confirm new password')),
                const SizedBox(height: 14),
                FilledButton.tonal(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: _changingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Change password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Sign out ──────────────────────────────────────────────
          AppCard.surface(
            context,
            padding: EdgeInsets.zero,
            color: cs.errorContainer.withValues(alpha: 0.4),
            child: ListTile(
              leading: Icon(Icons.logout, color: cs.onErrorContainer),
              title: Text('Sign out',
                  style: AppTypography.cardTitle
                      .copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w600)),
              subtitle: Text('Revokes this device token on the server.',
                  style:
                      AppTypography.secondary.copyWith(color: cs.onErrorContainer)),
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'LeadX Employee App · ${AppConstants.appName}',
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  String _currencyLine(BuildContext context) {
    final cfg = context.watch<AppConfigService>().currency;
    return '${cfg.symbol} ${cfg.code} · ${cfg.decimalPlaces} decimals · symbol ${cfg.symbolPosition}';
  }
}

/// Theme-mode row bound to the persisted preferences.
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeController>();
    final selectedIndex = switch (theme.mode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance Mode',
                      style: AppTypography.body.copyWith(color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    'Select theme appearance',
                    style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: NativeSegmentedControl(
            labels: const ['System', 'Light', 'Dark'],
            selectedIndex: selectedIndex,
            onValueChanged: (index) {
              final next = switch (index) {
                1 => ThemeMode.light,
                2 => ThemeMode.dark,
                _ => ThemeMode.system,
              };
              theme.setMode(next);
            },
            selectedColor: cs.primary,
            selectedTextColor: cs.onPrimary,
          ),
        ),
      ],
    );
  }
}

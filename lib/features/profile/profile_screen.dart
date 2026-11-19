import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/native_chrome.dart';
import '../../core/design/theme_controller.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/app_services.dart';
import '../../core/utils/native_banner_helper.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';

/// Profile: identity view, contact-field & username edits, password change,
/// appearance preferences, and logout. Role/team/permissions are
/// admin-managed and can never be sent (the backend rejects them).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _curPass = TextEditingController();
  final _newPass = TextEditingController();
  final _confPass = TextEditingController();

  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _obscureConf = true;

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
    final me = auth.me?.data;
    _nameCtrl.text = me?.name ?? '';
    _userCtrl.text = me?.username ?? '';
    _phoneCtrl.text = me?.phone ?? '';
    _emailCtrl.text = me?.email ?? '';
  }

  Future<void> _saveContact() async {
    setState(() {
      _saving = true;
      _msg = null;
    });

    final payload = <String, dynamic>{
      if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
      if (_userCtrl.text.trim().isNotEmpty) 'username': _userCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
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
        _msg = 'Profile details updated successfully.';
        _msgType = 'ok';
      });
      context.read<AuthController>().refreshMe();
      showLeadxBanner(
        context,
        title: 'Profile Updated',
        body: 'Your profile and username have been saved.',
        icon: const NativeIcon.symbol('checkmark.circle.fill', fallback: Icons.check_circle),
      );
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
      showLeadxBanner(
        context,
        title: 'Password Changed',
        body: 'Your password was updated successfully.',
        icon: const NativeIcon.symbol('lock.fill', fallback: Icons.lock),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _msg = e.isValidation
            ? (e.fieldErrors.values.isNotEmpty
                ? e.fieldErrors.values.first.first
                : 'Password change rejected (check current password).')
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
    _userCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _curPass.dispose();
    _newPass.dispose();
    _confPass.dispose();
    super.dispose();
  }

  Widget _buildField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    String? hintText,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Icon(
                prefixIcon,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13.5,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              ?suffix,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222226) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          capsule: false,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ── Message Banner ──────────────────────────────────────
            if (_msg != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _msgType == 'err'
                      ? (isDark ? const Color(0xFF3F1B1B) : const Color(0xFFFEE2E2))
                      : _msgType == 'warn'
                          ? (isDark ? const Color(0xFF3F311B) : const Color(0xFFFEF3C7))
                          : (isDark ? const Color(0xFF1B3F27) : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _msgType == 'err'
                        ? const Color(0xFFEF4444)
                        : _msgType == 'warn'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF22C55E),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _msgType == 'err'
                          ? Icons.error_outline_rounded
                          : _msgType == 'warn'
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: _msgType == 'err'
                          ? const Color(0xFFEF4444)
                          : _msgType == 'warn'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _msg!,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _msgType == 'err'
                              ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                              : _msgType == 'warn'
                                  ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                  : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Profile Card ─────────────────────────────────────────
            if (emp != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    // Avatar & Monogram with Status Dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF2E2E36) : const Color(0xFF171717),
                            border: Border.all(
                              color: isDark ? const Color(0xFF44444C) : const Color(0xFF262626),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              emp.name.trim().isNotEmpty ? emp.name.trim()[0].toUpperCase() : 'E',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Full Name
                    Text(
                      emp.name,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (emp.email != null && emp.email!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        emp.email!,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 10),
                    // Username & Account Status Pills
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF26262B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '@${emp.username}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: emp.username ?? ''));
                                  showLeadxBanner(
                                    context,
                                    title: 'Copied',
                                    body: '@${emp.username} copied to clipboard',
                                    icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                                  );
                                },
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          status: '${emp.status ?? 'active'} Account',
                          type: (emp.status ?? 'active') == 'active' ? 'success' : 'danger',
                          compact: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 14),

                    // 2x2 Grid of Account Detail Tiles
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailTile(
                            context: context,
                            label: 'Employee ID',
                            value: '#${emp.id}',
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailTile(
                            context: context,
                            label: 'System Role',
                            value: (emp.role ?? 'Employee').toUpperCase(),
                            icon: Icons.shield_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailTile(
                            context: context,
                            label: 'Assigned Team',
                            value: emp.team?.teamName ?? 'None',
                            icon: Icons.groups_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailTile(
                            context: context,
                            label: 'Team Code',
                            value: emp.team?.teamCode ?? '—',
                            icon: Icons.tag_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222226) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Team assignment and role permissions are managed exclusively by Super Admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Personal Information / Contact Details ────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Full Name
                  _buildField(
                    context: context,
                    label: 'Full Name',
                    controller: _nameCtrl,
                    prefixIcon: Icons.person_outline_rounded,
                    hintText: 'Enter your full name',
                  ),
                  const SizedBox(height: 12),

                  // Editable Username
                  _buildField(
                    context: context,
                    label: 'Username',
                    controller: _userCtrl,
                    prefixIcon: Icons.alternate_email_rounded,
                    hintText: 'Choose a unique username',
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  _buildField(
                    context: context,
                    label: 'Phone Number',
                    controller: _phoneCtrl,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    hintText: 'Enter your phone number',
                  ),
                  const SizedBox(height: 12),

                  // Email
                  _buildField(
                    context: context,
                    label: 'Email Address',
                    controller: _emailCtrl,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'Enter your email address',
                  ),
                  const SizedBox(height: 18),

                  // Save Profile Button
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF171717),
                        foregroundColor: isDark ? const Color(0xFF171717) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _saving ? null : _saveContact,
                      child: _saving
                          ? const LeadxFlickrLoading(size: 24)
                          : const Text(
                              'Save profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Appearance & Preferences ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 19, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance & Preferences',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _AppearanceRow(),
                  const Divider(height: 24),
                  // Display Currency
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Display currency',
                              style: AppTypography.body.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyLine(context),
                              style: AppTypography.secondary.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sync_rounded, size: 20),
                        color: cs.primary,
                        onPressed: () => context.read<AppConfigService>().refresh(),
                        tooltip: 'Sync currency config',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Change Password ───────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 19, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Change Password',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Changing the password signs out this account on all other devices.',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Current Password
                  _buildField(
                    context: context,
                    label: 'Current Password',
                    controller: _curPass,
                    prefixIcon: Icons.key_outlined,
                    obscureText: _obscureCur,
                    hintText: 'Enter your current password',
                    suffix: IconButton(
                      icon: Icon(
                        _obscureCur ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _obscureCur = !_obscureCur),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // New Password
                  _buildField(
                    context: context,
                    label: 'New Password',
                    controller: _newPass,
                    prefixIcon: Icons.lock_reset_rounded,
                    obscureText: _obscureNew,
                    hintText: 'At least 8 characters with numbers & letters',
                    suffix: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Confirm Password
                  _buildField(
                    context: context,
                    label: 'Confirm New Password',
                    controller: _confPass,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscureConf,
                    hintText: 'Re-enter your new password',
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => _obscureConf = !_obscureConf),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: BorderSide(
                          color: isDark ? const Color(0xFF333338) : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _changingPassword ? null : _changePassword,
                      child: _changingPassword
                          ? const LeadxFlickrLoading(size: 24)
                          : const Text(
                              'Update Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Sign Out ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E1919) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF4C1D24) : const Color(0xFFFFE4E6),
                  width: 1,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _logout,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sign out',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Revokes this device token on the server.',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

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
                      style: AppTypography.body.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Select theme appearance',
                    style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant, fontSize: 12),
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

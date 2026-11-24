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
import '../../core/services/biometric_service.dart';
import '../../core/update/app_update_controller.dart';
import '../../core/update/app_update_service.dart';
import '../../core/update/update_dialog.dart';
import '../../core/utils/native_banner_helper.dart';
import '../../core/utils/native_feedback.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_controller.dart';

/// Profile & Settings Screen redesigned to match the modern Stitch design system.
/// Supports both dynamic Light and Dark modes with responsive styling.
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

  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  bool _lockOnResume = false;

  /// Installed version string for the About row (`2.0.8`), read once.
  String _installedVersion = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _seed();
    _loadBiometricSettings();
    _loadInstalledVersion();
  }

  Future<void> _loadInstalledVersion() async {
    final info = await AppUpdateService.instance.packageInfo();
    if (!mounted || info == null) return;
    setState(() {
      _installedVersion = info.buildNumber.trim().isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})';
    });
  }

  /// Manual update check from the About card. Reports "up to date" inline and
  /// hands off to the same sheet the startup check uses.
  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    NativeFeedback.light();
    setState(() => _checkingUpdate = true);

    final controller = context.read<AppUpdateController>();
    final result = await controller.checkNow();

    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (result == null) {
      showLeadxBanner(
        context,
        title: 'Update check failed',
        body: 'Could not reach the update server. Check your connection and try again.',
        icon: const NativeIcon.symbol('wifi.exclamationmark', fallback: Icons.wifi_off_rounded),
      );
      return;
    }

    if (result.isActionable) {
      // A mandatory release can't be postponed — the gate will re-raise it,
      // so this manual path always opens the sheet.
      await UpdateDialog.show(context, result);
      return;
    }

    showLeadxBanner(
      context,
      title: 'LeadX is up to date',
      body: result.latestVersion == null
          ? 'You have the latest version installed.'
          : 'Version ${result.latestVersion!.versionName} is the latest release.',
      icon: const NativeIcon.symbol('checkmark.seal.fill', fallback: Icons.verified_rounded),
    );
  }

  Future<void> _loadBiometricSettings() async {
    final supported = await BiometricService.shared.canAuthenticate();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = BiometricService.shared.isBiometricEnabled;
      _lockOnResume = BiometricService.shared.lockOnResume;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    NativeFeedback.selection();
    if (value) {
      final result = await BiometricService.shared.authenticateDetailed(
        reason: 'Authenticate to enable biometric protection for LeadX',
      );
      if (!result.success) {
        if (!mounted) return;
        showLeadxBanner(
          context,
          title: 'Authentication Failed',
          body: result.errorMessage ?? 'Biometric unlock could not be verified.',
          icon: const NativeIcon.symbol('xmark.circle.fill', fallback: Icons.cancel_outlined),
        );
        return;
      }
    }
    await BiometricService.shared.setBiometricEnabled(value);
    await BiometricService.shared.setLockOnResume(value);
    if (!mounted) return;
    setState(() {
      _biometricEnabled = value;
      _lockOnResume = value;
    });
    showLeadxBanner(
      context,
      title: value ? 'Biometrics Activated' : 'Biometrics Deactivated',
      body: value
          ? 'LeadX is now protected with biometric unlock.'
          : 'Biometric verification has been disabled.',
      icon: NativeIcon.symbol(
        value ? 'faceid' : 'lock.open',
        fallback: value ? Icons.fingerprint_rounded : Icons.lock_open_rounded,
      ),
    );
  }

  Future<void> _toggleLockOnResume(bool value) async {
    NativeFeedback.selection();
    await BiometricService.shared.setLockOnResume(value);
    if (!mounted) return;
    setState(() {
      _lockOnResume = value;
    });
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
        _msg = 'Password changed. Other devices of this account were signed out.';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emp = auth.me?.data;
    final canPop = Navigator.of(context).canPop();

    // Stitch Design Color Tokens
    final pageBg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: pageBg,
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
          icon: NativeIcon.symbol('person.fill', fallback: Icons.person_rounded),
          capsule: true,
        ),
        trailing: [
          NativeBarButton(
            icon: const NativeIcon.symbol('ellipsis', fallback: Icons.more_horiz_rounded),
            onPressed: () => _showQuickActionsMenu(context),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Feedback Banner ───────────────────────────────────────
            if (_msg != null) ...[
              _buildFeedbackBanner(isDark: isDark),
              const SizedBox(height: 14),
            ],

            // ── User Identity Card ────────────────────────────────────
            if (emp != null) ...[
              _buildUserProfileCard(
                emp: emp,
                isDark: isDark,
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 16),
            ],

            // ── Contact Details Form ──────────────────────────────────
            _buildContactDetailsCard(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── Appearance & Preferences ──────────────────────────────
            _buildAppearanceCard(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── Security & Biometrics ─────────────────────────────────
            _buildSecurityBiometricsCard(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── Change Password Section ───────────────────────────────
            _buildPasswordCard(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── About & Updates ───────────────────────────────────────
            _buildAboutCard(
              isDark: isDark,
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),

            // ── Sign Out Danger Zone ──────────────────────────────────
            _buildSignOutDangerZone(isDark: isDark),
            const SizedBox(height: 20),

            // ── Footer Note ───────────────────────────────────────────
            Center(
              child: Text(
                _installedVersion.isEmpty
                    ? 'LeadX Employee App · ${AppConstants.appName}'
                    : 'LeadX Employee App · ${AppConstants.appName} · v$_installedVersion',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions Bottom Sheet ──────────────────────────────────────
  void _showQuickActionsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Refresh Profile'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<AuthController>().refreshMe();
                    showLeadxBanner(
                      context,
                      title: 'Refreshed',
                      body: 'Profile synced with server.',
                      icon: const NativeIcon.symbol('arrow.clockwise', fallback: Icons.refresh),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded),
                  title: const Text('Sync Currency Settings'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<AppConfigService>().refresh();
                    showLeadxBanner(
                      context,
                      title: 'Currency Synced',
                      body: 'Display currency refreshed.',
                      icon: const NativeIcon.symbol('indianrupeesign', fallback: Icons.currency_rupee),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Feedback Banner ─────────────────────────────────────────────────
  Widget _buildFeedbackBanner({required bool isDark}) {
    final isErr = _msgType == 'err';
    final isWarn = _msgType == 'warn';

    final bg = isErr
        ? (isDark ? const Color(0xFF3F1B1B) : const Color(0xFFFEE2E2))
        : isWarn
            ? (isDark ? const Color(0xFF3F311B) : const Color(0xFFFEF3C7))
            : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7));

    final border = isErr
        ? const Color(0xFFEF4444)
        : isWarn
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);

    final textColor = isErr
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
        : isWarn
            ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
            : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isErr
                ? Icons.error_outline_rounded
                : isWarn
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
            size: 18,
            color: border,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _msg!,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. User Profile Card ────────────────────────────────────────────
  Widget _buildUserProfileCard({
    required dynamic emp,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    // Subtle top accent gradient line
    final accentGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF38BDF8), Color(0xFF34D399)],
          )
        : const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF334155), Color(0xFF94A3B8)],
          );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Top Accent Gradient Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3.5,
            child: Container(
              decoration: BoxDecoration(gradient: accentGradient),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Column(
              children: [
                // Avatar Squircle & Monogram with Online Ring
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)]
                              : const [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          emp.name.trim().isNotEmpty
                              ? emp.name.trim()[0].toUpperCase()
                              : 'E',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name
                Text(
                  emp.name,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Email
                if (emp.email != null && emp.email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    emp.email!,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),

                // Badges Row: Monospace Username & Active Status Pill
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Username Pill (Tap to Copy)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: emp.username ?? ''));
                        showLeadxBanner(
                          context,
                          title: 'Copied',
                          body: '@${emp.username} copied to clipboard',
                          icon: const NativeIcon.symbol('doc.on.doc', fallback: Icons.copy),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 11,
                              color: textSecondary.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Active Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF065F46)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Active Account',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 14),

                // 2x2 Metadata Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetadataTile(
                        label: 'Employee ID',
                        value: '#${emp.id}',
                        isMonospace: true,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetadataTile(
                        label: 'System Role',
                        value: (emp.role ?? 'EMPLOYEE').toUpperCase(),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetadataTile(
                        label: 'Assigned Team',
                        value: emp.team?.teamName ?? 'Opuszen',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetadataTile(
                        label: 'Team Code',
                        value: emp.team?.teamCode ?? 'OZEN',
                        isMonospace: true,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                // Super Admin Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF020617).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Team assignment and role permissions are managed exclusively by Super Admin.',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataTile({
    required String label,
    required String value,
    required bool isDark,
    bool isMonospace = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020617).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: isMonospace ? 'monospace' : AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: isMonospace ? 0.3 : -0.1,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 2. Contact Details Section ──────────────────────────────────────
  Widget _buildContactDetailsCard({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with "Editable" badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONTACT DETAILS',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  'Editable',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name Input
          _buildStitchInputField(
            label: 'Name',
            controller: _nameCtrl,
            placeholder: 'Enter your full name',
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Username Input
          _buildStitchInputField(
            label: 'Username',
            controller: _userCtrl,
            placeholder: 'Choose a unique username',
            isDark: isDark,
            isMonospace: true,
          ),
          const SizedBox(height: 12),

          // Phone Input
          _buildStitchInputField(
            label: 'Phone',
            controller: _phoneCtrl,
            placeholder: 'Enter phone number',
            keyboardType: TextInputType.phone,
            isDark: isDark,
            isMonospace: true,
          ),
          const SizedBox(height: 12),

          // Email Input
          _buildStitchInputField(
            label: 'Email',
            controller: _emailCtrl,
            placeholder: 'name@company.com',
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // Save Profile Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                elevation: isDark ? 2 : 1,
                shadowColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFF0F172A).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving ? null : _saveContact,
              child: _saving
                  ? const LeadxFlickrLoading(size: 22)
                  : const Text(
                      'Save profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool isMonospace = false,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final fieldBg = isDark ? const Color(0xFF020617).withValues(alpha: 0.8) : const Color(0xFFF8FAFC);
    final fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fieldBorder, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontFamily: isMonospace ? 'monospace' : AppTypography.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: TextStyle(
                      fontFamily: isMonospace ? 'monospace' : AppTypography.fontFamily,
                      fontSize: 13,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

  // ── 3. Appearance & Preferences Section ─────────────────────────────
  Widget _buildAppearanceCard({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final theme = context.watch<ThemeController>();
    final selectedIndex = switch (theme.mode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'APPEARANCE & PREFERENCES',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Appearance Mode Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.transparent,
                  ),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance Mode',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Select theme appearance',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-Option Segmented Control matching Stitch
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                _buildSegmentButton(
                  title: 'System',
                  selected: selectedIndex == 0,
                  isDark: isDark,
                  onTap: () => theme.setMode(ThemeMode.system),
                ),
                _buildSegmentButton(
                  title: 'Light',
                  selected: selectedIndex == 1,
                  isDark: isDark,
                  onTap: () => theme.setMode(ThemeMode.light),
                ),
                _buildSegmentButton(
                  title: 'Dark',
                  selected: selectedIndex == 2,
                  isDark: isDark,
                  onTap: () => theme.setMode(ThemeMode.dark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),

          // Display Currency Setting
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display currency',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyLine(context),
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  context.read<AppConfigService>().refresh();
                  showLeadxBanner(
                    context,
                    title: 'Currency Synced',
                    body: 'Currency configuration synced with backend.',
                    icon: const NativeIcon.symbol('indianrupeesign', fallback: Icons.sync),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.sync_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? (isDark ? const Color(0xFF020617) : Colors.white)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  // ── 3b. Security & Biometrics Section ──────────────────────────────
  Widget _buildSecurityBiometricsCard({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECURITY & BIOMETRICS',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Biometric Unlock Switch
          InkWell(
            onTap: _biometricSupported
                ? () => _toggleBiometrics(!_biometricEnabled)
                : () {
                    showLeadxBanner(
                      context,
                      title: 'Biometrics Unavailable',
                      body: 'No fingerprint, Face ID, or screen lock detected. Please enable a screen lock PIN, pattern, or biometrics in device settings.',
                      icon: const NativeIcon.symbol('exclamationmark.triangle.fill', fallback: Icons.warning_amber_rounded),
                    );
                  },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biometric Unlock',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        _biometricSupported
                            ? 'Fingerprint or Face ID login protection'
                            : 'Tap to see requirements (PIN/Fingerprint)',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _biometricEnabled,
                  activeThumbColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  onChanged: _biometricSupported ? _toggleBiometrics : null,
                ),
              ],
            ),
          ),

          if (_biometricSupported && _biometricEnabled) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 14),

            // Lock on Resume Switch
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: 19,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lock App on Resume',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Prompt biometrics when reopening app',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _lockOnResume,
                  activeThumbColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  onChanged: _toggleLockOnResume,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 4. Change Password Section ──────────────────────────────────────
  Widget _buildPasswordCard({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change password',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Changing the password signs out this account on all other devices.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Current Password
          _buildStitchInputField(
            label: 'Current password',
            controller: _curPass,
            placeholder: 'Current password',
            obscureText: _obscureCur,
            isDark: isDark,
            suffix: IconButton(
              icon: Icon(
                _obscureCur ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: textSecondary,
              ),
              onPressed: () => setState(() => _obscureCur = !_obscureCur),
            ),
          ),
          const SizedBox(height: 12),

          // New Password
          _buildStitchInputField(
            label: 'New password',
            controller: _newPass,
            placeholder: 'New password (8+ chars)',
            obscureText: _obscureNew,
            isDark: isDark,
            suffix: IconButton(
              icon: Icon(
                _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: textSecondary,
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          const SizedBox(height: 12),

          // Confirm New Password
          _buildStitchInputField(
            label: 'Confirm new password',
            controller: _confPass,
            placeholder: 'Confirm new password',
            obscureText: _obscureConf,
            isDark: isDark,
            suffix: IconButton(
              icon: Icon(
                _obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: textSecondary,
              ),
              onPressed: () => setState(() => _obscureConf = !_obscureConf),
            ),
          ),
          const SizedBox(height: 18),

          // Submit Password Change Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                elevation: isDark ? 2 : 1,
                shadowColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFF0F172A).withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _changingPassword ? null : _changePassword,
              child: _changingPassword
                  ? const LeadxFlickrLoading(size: 22)
                  : const Text(
                      'Change password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Sign Out Danger Zone ─────────────────────────────────────────
  Widget _buildSignOutDangerZone({required bool isDark}) {
    final dangerBg = isDark ? const Color(0xFF1C0D11) : const Color(0xFFFFF1F2);
    final dangerBorder = isDark ? const Color(0xFF4C1D24) : const Color(0xFFFFE4E6);
    final iconBoxBg = isDark ? const Color(0xFF2E1217) : Colors.white;
    final iconBoxBorder = isDark ? const Color(0xFF881337) : const Color(0xFFFECDD3);
    final iconColor = isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);

    return InkWell(
      onTap: _logout,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: dangerBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dangerBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBoxBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBoxBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.logout_rounded,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign out',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Revokes this device token on the server.',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: iconColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: iconColor.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. About & Updates Section ──────────────────────────────────────
  Widget _buildAboutCard({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final tileBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final tileBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final controller = context.watch<AppUpdateController>();
    final pending = controller.result;
    final hasUpdate = pending?.isActionable ?? false;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT & UPDATES',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Installed version + manual check
          InkWell(
            onTap: _checkingUpdate ? null : _checkForUpdates,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tileBorder),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 19,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App version',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        _installedVersion.isEmpty
                            ? 'Tap to check for updates'
                            : '$_installedVersion · tap to check for updates',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_checkingUpdate)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textSecondary),
                    ),
                  )
                else if (hasUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AVAILABLE',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
              ],
            ),
          ),

          if (pending != null && hasUpdate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: () => UpdateDialog.show(context, pending),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Update to ${pending.latestVersion?.versionName ?? 'latest'}',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _currencyLine(BuildContext context) {
    final cfg = context.watch<AppConfigService>().currency;
    return '${cfg.symbol} ${cfg.code} · ${cfg.decimalPlaces} decimals · symbol ${cfg.symbolPosition}';
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/dev_support_service.dart';
import '../../shared/widgets/developer_support_bar.dart';
import 'auth_controller.dart';

/// Screen 12: `employee/login`
///
/// Flat B2B SaaS sign-in: a solid white card (radius 12, subtle 1px
/// shadow) on a flat off-white surface — no glass chrome, no gradients,
/// no decorative orbs. The primary action is a solid near-black
/// [AppColors.brand] button; inputs use light-grey borders and a
/// neutral 2px focus ring.
///
/// - Centered, responsive (max 380 wide), never full screen; the form
///   scrolls inside a SafeArea when the keyboard opens.
/// - The Sign In button is full-width, shows a spinner while busy and is
///   disabled during authentication (double-submit is blocked).
/// - "Remember me" is UI-only: the backend login endpoint cannot honor
///   it yet, so the state is not sent with the request.
/// - A tappable "Developer Support" section at the bottom runs the
///   [DevSupportService] fallback chain (email app → Gmail web → copy).
class LoginScreen extends StatefulWidget {
  /// Injectable for tests (the support fallback chain).
  const LoginScreen({super.key, this.supportService});

  final DevSupportService? supportService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  late final AnimationController _entrance; // ≤200ms opacity-only card fade

  bool _obscure = true;
  bool _busy = false;
  bool _rememberMe = false;
  String? _userError;
  String? _passError;

  DevSupportService get _support =>
      widget.supportService ?? DevSupportService();

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      // §1 motion: ≤200ms, opacity-only (scale stripped).
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _entrance.dispose();
    super.dispose();
  }

  // ── Validation + Auth ──────────────────────────────────────────────

  /// Validates both fields, records inline errors, and focuses the first
  /// invalid input. Returns true when the form is ready to submit.
  bool _validate() {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    final userError =
        user.isEmpty ? 'Please enter your username or email' : null;
    final passError = pass.isEmpty ? 'Please enter your password' : null;

    setState(() {
      _userError = userError;
      _passError = passError;
    });

    if (userError != null) {
      _userFocus.requestFocus();
      return false;
    }
    if (passError != null) {
      _passFocus.requestFocus();
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate() || _busy) return;
    setState(() => _busy = true);

    final auth = context.read<AuthController>();
    try {
      final ok = await auth.login(
        _userCtrl.text.trim(),
        _passCtrl.text,
        remember: _rememberMe,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Invalid credentials or inactive account.',
                    textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        final message = e.isValidation
            ? (e.fieldErrors.values.isNotEmpty
                ? e.fieldErrors.values.first.first
                : 'Please verify your credentials.')
            : (e.statusCode == 429
                ? 'Too many login attempts. Please wait 15 minutes.'
                : e.message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.center),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not reach the server. Please check your internet connection.',
                textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearUserError() {
    if (_userError != null) setState(() => _userError = null);
  }

  void _clearPassError() {
    if (_passError != null) setState(() => _passError = null);
  }

  // ── Shared pieces ──────────────────────────────────────────────────

  /// The preserved LeadX brand badge (flat neutral treatment).
  Widget _logoBadge(ColorScheme cs) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: ClipOval(
          child: Image.asset(
            'assets/images/leadx_logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  /// 48px+ input (16px text + 14/16 content padding), radius 8, 1px
  /// light-grey border, neutral 2px focus ring (neither blue nor green).
  InputDecoration _fieldDecoration(
    IconData icon,
    String label,
    String hint,
    ColorScheme cs, {
    Widget? suffix,
    String? error,
  }) {
    const r = AppColors.radiusMd; // 8
    final danger = StatusPalette.danger(cs);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: cs.surface,
      labelStyle:
          AppTypography.body.copyWith(fontSize: 14, color: cs.onSurfaceVariant),
      hintStyle:
          AppTypography.body.copyWith(fontSize: 14, color: cs.onSurfaceVariant),
      errorStyle: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 12,
      ).copyWith(color: danger),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        // 1px #E5E5E5 in light (the theme pins surfaceContainerHighest to
        // exactly that tone), a quiet neutral on dark surfaces.
        borderSide: BorderSide(color: cs.surfaceContainerHighest),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        // Neutral 2px focus ring — deliberately not blue/green.
        borderSide: BorderSide(color: cs.outline, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: danger, width: 2),
      ),
    );
  }

  Widget _spinner(Color fg) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
    );
  }

  /// The full-width Sign In CTA: solid near-black (white in dark mode),
  /// white semibold 15px label, 52px tall, radius 12. Spinner + disabled
  /// while busy; [_submit] blocks re-entry so double-taps cannot queue
  /// a second request.
  Widget _signInButton(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final bg = isDark ? AppColors.brandDark : AppColors.brand;
    final fg = cs.onPrimary; // white on the near-black light button
    return FilledButton(
      onPressed: _busy ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: bg.withValues(alpha: 0.55),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        textStyle: AppTypography.body.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
      child: _busy ? _spinner(fg) : const Text('Sign In'),
    );
  }

  /// UI-only "Remember me" row. The backend login cannot honor it yet,
  /// so the value is local to this screen and never sent.
  Widget _rememberMeRow(ColorScheme cs) {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged:
              _busy ? null : (v) => setState(() => _rememberMe = v ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 4),
        Text(
          'Remember me',
          style: AppTypography.secondary.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _securityNote(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Laravel Sanctum Protected · 5 attempts / 15 min',
          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  // ── Card (solid SaaS surface, always rendered) ─────────────────────

  Widget _card(ColorScheme cs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg), // 12
        border: Border.all(color: cs.surfaceContainerHighest),
        // Spec §1: 0 1px 2px rgba(0,0,0,.05) — subtle, no glass.
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _logoBadge(cs),
            const SizedBox(height: 18),
            Text(
              'Employee Login',
              textAlign: TextAlign.center,
              style: AppTypography.pageTitle.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in with your employee account to manage orders, '
              'follow-ups, and performance.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                  color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 24),
            // Username / Email — user icon, proper alignment + padding.
            TextFormField(
              controller: _userCtrl,
              focusNode: _userFocus,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _passFocus.requestFocus(),
              onChanged: (_) => _clearUserError(),
              style: AppTypography.body.copyWith(color: cs.onSurface),
              decoration: _fieldDecoration(
                Icons.person_outline,
                'Username or Email',
                'jane.doe or jane@company.com',
                cs,
                error: _userError,
              ),
            ),
            const SizedBox(height: 8),
            // Password — lock icon + show/hide.
            TextFormField(
              controller: _passCtrl,
              focusNode: _passFocus,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              onChanged: (_) => _clearPassError(),
              style: AppTypography.body.copyWith(color: cs.onSurface),
              decoration: _fieldDecoration(
                Icons.lock_outline,
                'Password',
                'Your password',
                cs,
                error: _passError,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed:
                      () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _rememberMeRow(cs),
            const SizedBox(height: 12),
            _signInButton(cs),
            const SizedBox(height: 12),
            _securityNote(cs),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // §1 motion: entrance is a ≤200ms opacity-only fade (no scale / no
    // layout shift) and is skipped entirely when the user prefers reduced
    // motion (MediaQuery.disableAnimationsOf).
    final animationsOff = MediaQuery.disableAnimationsOf(context);
    final card = _card(cs);
    final entranceCard = animationsOff
        ? card
        : FadeTransition(opacity: _entrance, child: card);

    return Scaffold(
      // Flat off-white (near-black in dark) — no orbs, no gradients.
      backgroundColor: cs.brightness == Brightness.dark
          ? AppColors.neutralBgDark
          : AppColors.neutralBgLight,
      body: Stack(
        children: [
          // The login card — centered, responsive, not full screen.
          // SafeArea + SingleChildScrollView handle small screens and the
          // keyboard (the card scrolls into view when the keyboard opens).
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: entranceCard,
                ),
              ),
            ),
          ),

          // The Developer Support section — fully tappable, with the
          // email → browser → copy fallback chain.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DeveloperSupportBar(service: _support),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_typography.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/app_config_service.dart';
import 'auth_controller.dart';

/// The single LeadX screen: the Employee login, styled to match
/// `leadx-employee-frontend/blade-views/auth/employee-login.blade.php` and
/// its standalone preview exactly (neutral SaaS palette, Inter type, the
/// heroicon eye / eye-off toggles, and the same alert grammar).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  bool _rememberMe = false;
  String? _userError;
  String? _passError;

  // Mirrors the blade's `session('info')` warning and `$errors` danger
  // alerts, rendered above the form inside the auth box.
  String? _info;
  String? _error;

  /// Exact heroicon (outline) SVGs from the blade's password toggle. The
  /// blade strokes with `currentColor` at `--c-neutral-400`, so the path
  /// strokes are pinned to #A3A3A3 (the web's neutral-400).
  static const String _eyeSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="#A3A3A3">'
      '<path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"/>'
      '<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/>'
      '</svg>';

  static const String _eyeOffSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="#A3A3A3">'
      '<path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 0 1-4.293 5.774M6.375 6.375a11.05 11.05 0 0 0-4.417 7.253.82.82 0 0 1-.371-.653c.005-.383.062-.76.167-1.123a9.626 9.626 0 0 1 5.016-5.968ZM18.375 18.375a11.05 11.05 0 0 0 4.417-7.253.82.82 0 0 1-.371-.653c-.005-.383.062-.76.167-1.123a9.626 9.626 0 0 1-5.016 5.968Z"/>'
      '</svg>';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ── Validation + Auth ──────────────────────────────────────────────

  bool _validate() {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    final userError =
        user.isEmpty ? 'Please enter your username or email' : null;
    final passError = pass.isEmpty ? 'Please enter your password' : null;

    setState(() {
      _userError = userError;
      _passError = passError;
      _error = null;
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
        setState(() {
          _error = 'Invalid credentials or inactive account.';
          _info = null;
        });
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
        setState(() {
          _error = message;
          _info = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the server. Please check your internet connection.';
          _info = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Design tokens (web app.css, light auth palette) ────────────────
  static const Color _neutral50 = Color(0xFFFAFAFA);
  static const Color _neutral200 = Color(0xFFE5E5E5);
  static const Color _neutral300 = Color(0xFFD4D4D4);
  static const Color _neutral400 = Color(0xFFA3A3A3);
  static const Color _neutral500 = Color(0xFF737373);
  static const Color _neutral600 = Color(0xFF525252);
  static const Color _neutral700 = Color(0xFF404040);
  static const Color _neutral800 = Color(0xFF262626);
  static const Color _neutral900 = Color(0xFF171717);

  static const Color _red50 = Color(0xFFFEF2F2);
  static const Color _red200 = Color(0xFFFECACA);
  static const Color _red600 = Color(0xFFDC2626);
  static const Color _red800 = Color(0xFF991B1B);
  static const Color _amber50 = Color(0xFFFFFBEB);
  static const Color _amber200 = Color(0xFFFDE68A);
  static const Color _amber800 = Color(0xFF92400E);
  static const Color _green50 = Color(0xFFF0FDF4);
  static const Color _green200 = Color(0xFFBBF7D0);
  static const Color _green800 = Color(0xFF166534);

  /// The CSS scales input text to 16px on phone-width viewports
  /// (`@media (max-width: 40rem)`) so the keyboard doesn't zoom.
  double get _inputFontSize =>
      MediaQuery.of(context).size.width <= 640 ? 16 : 14;

  // ── Blade elements ─────────────────────────────────────────────────

  /// `.auth-brand--stacked` → logo (52px tall, max 160px wide, contain)
  /// with the 20px semibold "Employee Login" title 12px below.
  Widget _brand() {
    final siteLogoUrl = context.watch<AppConfigService>().siteLogoUrl;

    Widget fallbackImage = Image.asset(
      'assets/images/leadx_logo.png',
      height: 52,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const _BrandFallback(),
    );

    Widget logoImage;
    if (siteLogoUrl != null && siteLogoUrl.isNotEmpty) {
      logoImage = Image.network(
        siteLogoUrl,
        height: 52,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => fallbackImage,
      );
    } else {
      logoImage = fallbackImage;
    }

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: logoImage,
        ),
        const SizedBox(height: 12), // sp-3, `.auth-page .auth-title`
        Text(
          'Employee Login',
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 20, // text-xl
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2, // -0.01em
            color: _neutral900,
          ),
        ),
      ],
    );
  }

  /// `.auth-box`: white card, 1px neutral-200 border, 16px radius, the
  /// web's `--shadow-md` (two soft stacked shadows).
  Widget _authBox({
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.fromBorderSide(BorderSide(color: _neutral200)),
        borderRadius: BorderRadius.all(Radius.circular(16)), // radius-xl
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000), // rgb(0 0 0 / 0.1)
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24), // sp-6
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  /// `.alert` family (warning = `session('info')`, danger = `$errors`):
  /// 14px text, 12/16 padding, 8px radius, 1px border, 16px bottom margin.
  Widget _alert({
    required String message,
    required Color bg,
    required Color border,
    required Color ink,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // sp-4
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8), // radius-md
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          height: 1.5,
          color: ink,
        ),
      ),
    );
  }

  /// `.form-group`: 14px medium neutral-700 label, 6px above the input;
  /// a 422 field error renders as a 12px red-600 line 6px below.
  Widget _formGroup({
    required String label,
    required Widget input,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _neutral700,
          ),
        ),
        const SizedBox(height: 6), // sp-1.5
        input,
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: _red600,
            ),
          ),
        ],
      ],
    );
  }

  /// `.form-input` inside `.auth-page`: 44px min height, 8px radius,
  /// neutral-300 border; focus → neutral-900 border + the 3px 10%-black
  /// ring the CSS applies on `:focus`. The disabled look (neutral-50
  /// fill, neutral-500 text) mirrors `.form-input:disabled`.
  Widget _authInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool enabled,
    bool obscure = false,
    Widget? suffix,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    ValueChanged<String>? onChanged,
    List<String>? autofillHints,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = enabled && focusNode.hasFocus;
        final field = IgnorePointer(
          ignoring: !enabled,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscure,
            autofillHints: enabled ? autofillHints : null,
            keyboardType:
                obscure ? TextInputType.text : TextInputType.emailAddress,
            textInputAction: textInputAction,
            onChanged: enabled ? onChanged : null,
            onSubmitted: onSubmitted,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: _inputFontSize,
              height: 1.5,
              color: enabled ? _neutral900 : _neutral500,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.fromLTRB(
                12, // sp-3
                14, // → 44px min height (2.75rem)
                // Web `.password-field .form-input` pads right 2.75rem so
                // the entered text never slips under the overlaid toggle.
                suffix != null ? 44 : 12,
                14,
              ),
              filled: true,
              fillColor: enabled ? Colors.white : _neutral50,
              // The Container above paints every visual state; keep the
              // field's own borders inert.
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              // No suffixIcon: InputDecorator would center it in the
              // field; the toggle is overlaid on the right edge instead.
            ),
          ),
        );
        return Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : _neutral50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focused ? _neutral900 : _neutral300,
              width: 1,
            ),
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: Color(0x1A171717), // rgb(23 23 23 / 0.1)
                      spreadRadius: 3,
                    ),
                  ]
                : const [],
          ),
          child: suffix == null
              ? field
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    field,
                    // Web `.password-toggle`: position absolute,
                    // right sp-2, vertically centered.
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(child: suffix),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// `.form-check` → "Remember me": 16px checkbox, 1px neutral-300
  /// border, 4px radius, neutral-900 accent; 14px neutral-600 label,
  /// 8px gap.
  Widget _rememberMeRow(bool enabled) {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged:
              enabled ? (v) => setState(() => _rememberMe = v ?? false) : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          activeColor: _neutral900,
          checkColor: Colors.white,
          side: const BorderSide(color: _neutral300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8), // sp-2
        Text(
          'Remember me',
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            color: _neutral600,
          ),
        ),
      ],
    );
  }

  /// `.btn .btn-primary .btn-block .btn-submit`: full width, 48px tall,
  /// 8px radius, neutral-900 fill (hover → neutral-800), 14px semibold
  /// white "Sign in". The `.is-loading` state — spinner replaces the
  /// label, 0.85 opacity, pointer-events locked — is the double-submit
  /// guard the blade's script installs on submit.
  Widget _submitButton(bool enabled) {
    return Container(
      width: double.infinity,
      height: 48, // 3rem
      decoration: BoxDecoration(
        color: _busy ? _neutral800 : _neutral900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Opacity(
        opacity: _busy ? 0.85 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled && !_busy ? _submit : null,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.35),
                      ),
                    )
                  : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.14, // 0.01em
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// `.password-toggle`: a 32×32 neutral-400 hit-target showing the eye icon
  /// while obscured and the eye-off icon while revealed (the blade's
  /// `aria-pressed` swap). The caller overlays this pinned to the field's
  /// right edge (web `.password-toggle` is `position:absolute; right: sp-2`);
  /// this widget is just the fixed-size button so the inset/centering lives
  /// in the input's overlay, not here.
  Widget _passwordToggle(bool enabled) {
    return SizedBox.square(
      dimension: 32, // 2rem button, web spec
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => setState(() => _obscure = !_obscure) : null,
        child: SvgPicture.string(
          _obscure ? _eyeSvg : _eyeOffSvg,
          width: 20,
          height: 20, // 1.25rem icon, web spec
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    // While the persisted session restores, the form reads as the web's
    // `:disabled` state; on success the whole box locks and reports.
    final signedIn = auth.isAuthenticated || auth.bootstrapping;
    final restoring = !auth.isAuthenticated && auth.bootstrapping;
    final enabled = !signedIn;

    return Scaffold(
      // `.auth-page` background → neutral-50 (#FAFAFA).
      backgroundColor: _neutral50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), // sp-4 page padding
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384), // 24rem
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _brand(),
                  const SizedBox(height: 20), // sp-5 (.auth-brand--stacked)
                  _authBox(
                    children: [
                      if (restoring)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _neutral400,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Restoring session…',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 14,
                                  color: _neutral500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!restoring) ...[
                        if (_error != null)
                          _alert(
                            message: _error!,
                            bg: _red50,
                            border: _red200,
                            ink: _red800,
                          ),
                        if (_info != null)
                          _alert(
                            message: _info!,
                            bg: _amber50,
                            border: _amber200,
                            ink: _amber800,
                          ),
                        if (auth.isAuthenticated)
                          _alert(
                            message:
                                'Signed in as ${auth.me?.data.name ?? ''}.',
                            bg: _green50,
                            border: _green200,
                            ink: _green800,
                          ),
                      ],
                      // `.auth-page .auth-box form`: 16px gap between groups.
                      ..._form(enabled: enabled),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The blade's form: username/email + password (heroicon eye toggle) +
  /// "Remember me" + full-width "Sign in", on the 16px vertical rhythm.
  List<Widget> _form({required bool enabled}) {
    return [
      _formGroup(
        label: 'Username or email',
        error: enabled ? _userError : null,
        input: _authInput(
          controller: _userCtrl,
          focusNode: _userFocus,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passFocus.requestFocus(),
          onChanged:
              _userError != null ? (_) => setState(() => _userError = null) : null,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
        ),
      ),
      const SizedBox(height: 16), // sp-4 form gap
      _formGroup(
        label: 'Password',
        error: enabled ? _passError : null,
        input: _authInput(
          controller: _passCtrl,
          focusNode: _passFocus,
          enabled: enabled,
          obscure: _obscure,
          suffix: _passwordToggle(enabled),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged:
              _passError != null ? (_) => setState(() => _passError = null) : null,
          autofillHints: const [AutofillHints.password],
        ),
      ),
      const SizedBox(height: 16),
      _rememberMeRow(enabled),
      const SizedBox(height: 16),
      _submitButton(enabled),
    ];
  }
}

/// `.auth-brand-icon` fallback: a 48px rounded neutral-900 tile with the
/// site initial, shown only if the logo asset is missing.
class _BrandFallback extends StatelessWidget {
  const _BrandFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: _LoginScreenState._neutral900,
        borderRadius: BorderRadius.all(Radius.circular(8)), // radius-md
      ),
      alignment: Alignment.center,
      child: const Text(
        'L',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

import 'package:url_launcher/url_launcher.dart';

/// Which step of the Developer Support fallback chain ended the attempt.
///
/// The chain is: (1) the device's default email app via `mailto:`,
/// (2) Gmail's web compose in the external browser, (3) neither could be
/// opened → the UI offers a "copy the address" fallback.
enum SupportLaunchOutcome {
  /// Step 1 succeeded — an email client opened pre-addressed to support.
  openedMailto,

  /// Step 2 succeeded — Gmail web compose opened in the browser.
  openedBrowser,

  /// Neither launcher worked; the caller should show the copy fallback.
  needsCopyFallback,
}

/// Centralized, platform-safe Developer Support launcher.
///
/// This is the single source of truth for the support address, default
/// subject/body, and the launch fallback chain, so the login screen (and any
/// future surface) never invents its own copy. Every launch step is wrapped
/// in `try/catch` so a missing email app, a missing browser, or a
/// `PlatformException` can never crash the app — the worst outcome is a copy
/// fallback.
///
/// [canLaunchUrl] / [launchUrl] are injectable for unit tests; the defaults
/// use [url_launcher].
class DevSupportService {
  DevSupportService({
    String? supportEmail,
    Future<bool> Function(Uri uri)? canLaunchUrl,
    Future<bool> Function(Uri uri, {LaunchMode? mode})? launchUrl,
  })  : _supportEmail = supportEmail ?? defaultSupportEmail,
        _canLaunchUrl = canLaunchUrl ?? _defaultCanLaunch,
        _launchUrl = launchUrl ?? _defaultLaunch;

  /// The official support address (set once here — no other copy lives in the
  /// UI layer).
  static const String defaultSupportEmail = 'premfxexe@gmail.com';

  /// Default subject for every support message.
  static const String defaultSubject =
      'LeadX Employee App - Developer Support';

  /// Default body. The version / model / OS fields are left as blanks the
  /// user fills in from the email client (they require native device-info
  /// plugins we deliberately do not bundle).
  static const String defaultBody = '''
Hello LeadX Developer Support Team,

I need assistance with the LeadX Employee App.

Issue Description:

App Version:

Device Model:

Android Version:

Thank you.
''';

  final String _supportEmail;
  final Future<bool> Function(Uri uri) _canLaunchUrl;
  final Future<bool> Function(Uri uri, {LaunchMode? mode}) _launchUrl;

  /// The support address. Exposed so the copy fallback can hand it to the
  /// clipboard; the address is intentionally never rendered as visible text
  /// on the login screen (only inside a launched message / copied value).
  String get supportEmail => _supportEmail;

  /// Step 1 target: the default email app, pre-addressed with subject + body.
  Uri get mailtoUri => Uri.parse(
        'mailto:$_supportEmail'
        '?subject=${Uri.encodeComponent(defaultSubject)}'
        '&body=${Uri.encodeComponent(defaultBody.trim())}',
      );

  /// Step 2 target: Gmail's web compose, pre-addressed with subject + body.
  /// Opened in the external browser when no email app is available.
  Uri get gmailWebUri => Uri.parse(
        'https://mail.google.com/mail/u/0/?view=cm&fs=1'
        '&to=${Uri.encodeComponent(_supportEmail)}'
        '&su=${Uri.encodeComponent(defaultSubject)}'
        '&body=${Uri.encodeComponent(defaultBody.trim())}',
      );

  /// Runs the whole fallback chain and reports which step succeeded.
  ///
  /// Never throws: a `PlatformException` or an unlaunchable URI is treated as
  /// "this step failed, try the next one."
  Future<SupportLaunchOutcome> openSupport() async {
    // Step 1 — default email app.
    try {
      if (await _canLaunchUrl(mailtoUri)) {
        final opened =
            await _launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
        if (opened) return SupportLaunchOutcome.openedMailto;
      }
    } catch (_) {
      // Fall through to the browser.
    }

    // Step 2 — Gmail web compose in the external browser.
    try {
      if (await _canLaunchUrl(gmailWebUri)) {
        final opened =
            await _launchUrl(gmailWebUri, mode: LaunchMode.externalApplication);
        if (opened) return SupportLaunchOutcome.openedBrowser;
      }
    } catch (_) {
      // Fall through to the copy fallback.
    }

    // Step 3 — nothing launched; offer to copy the address.
    return SupportLaunchOutcome.needsCopyFallback;
  }

  // ── Defaults: the real url_launcher, made crash-proof. ──────────────

  static Future<bool> _defaultCanLaunch(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _defaultLaunch(Uri uri, {LaunchMode? mode}) async {
    try {
      return await launchUrl(uri, mode: mode ?? LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

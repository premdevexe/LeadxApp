import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/biometric_service.dart';
import 'app_update_controller.dart';
import 'update_dialog.dart';
import 'update_model.dart';

/// Watches [AppUpdateController] and presents the update sheet at the right
/// moment.
///
/// It wraps the authenticated shell rather than sitting inside any one
/// screen, so the prompt is available on every tab and survives navigation.
/// Deferral rules:
/// - never interrupt the biometric lock screen — that overlay owns input;
/// - never stack a second sheet on top of an already-open one;
/// - never interrupt another route (a detail screen, a form), wait until the
///   shell is the visible route again.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  static const int _maxRetries = 4;

  /// How many times a *mandatory* sheet may be re-raised after the user
  /// closed it without installing, per session. A force-update genuinely
  /// cannot be skipped, but an install can also be impossible (the device
  /// can't parse the APK, "unknown sources" is blocked by policy), and an
  /// infinite dialog loop would leave them with no usable app at all.
  static const int _maxMandatoryRePrompts = 3;
  static const Duration _mandatoryRePromptDelay = Duration(seconds: 6);

  AppUpdateController? _controller;
  bool _presenting = false;
  bool _retryScheduled = false;
  int _retries = 0;
  int _mandatoryRePrompts = 0;
  bool _mandatoryRePromptScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check for update whenever user opens or resumes the app
      _controller?.checkNow();
    }
  }

  void _attach() {
    if (!mounted) return;
    final controller = context.read<AppUpdateController>();
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_onControllerChanged);
    _controller = controller;
    controller.addListener(_onControllerChanged);
    // `start()` kicks off a network check and notifies listeners. Never do
    // that while the tree is building — the provider scope would be marked
    // dirty mid-build.
    controller.start();
    _onControllerChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    // The shell is going away (usually a logout). Stop polling the portal
    // until a new session mounts this gate again.
    _controller?.stop();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _presenting) return;
    final controller = _controller;
    if (controller == null) return;
    if (!controller.shouldPrompt()) return;
    final info = controller.result;
    if (info == null) return;

    if (!_isSafeToPresent()) {
      _scheduleRetry();
      return;
    }
    _present(info);
  }

  /// The shell must be the top route, and the biometric lock must be up.
  bool _isSafeToPresent() {
    if (!mounted) return false;
    if (BiometricService.shared.isAuthenticating) return false;
    if (BiometricService.shared.isAppLocked) return false;
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  /// Re-evaluate shortly. Used when the shell isn't the visible route yet —
  /// a dialog or a pushed detail screen will close soon enough.
  ///
  /// Backs off and gives up after [_maxRetries] so a screen that stays on
  /// top for a long time (a form being filled in) can't leave a timer
  /// polling for the rest of the session. The next controller notification
  /// — a fresh check or a new release — restarts the attempt.
  void _scheduleRetry() {
    if (_retryScheduled) return;
    _retryScheduled = true;
    if (_retries >= _maxRetries) {
      _retryScheduled = false;
      return;
    }
    final delay = Duration(milliseconds: 500 * (1 << _retries));
    _retries++;
    Future<void>.delayed(delay, () {
      _retryScheduled = false;
      _onControllerChanged();
    });
  }

  Future<void> _present(UpdateCheckResult info) async {
    _presenting = true;
    _retries = 0;
    try {
      final installed = await UpdateDialog.show(context, info);
      if (!mounted) return;
      if (installed) return;

      if (!info.isMandatory) {
        // Optional release postponed — don't raise it again this session.
        _controller?.dismissPrompt(info.latestVersion?.versionCode ?? 0);
        return;
      }
      _scheduleMandatoryRePrompt();
    } finally {
      _presenting = false;
    }
  }

  /// A mandatory release was closed without installing. Re-raise it after a
  /// short pause, but only so many times per session — see
  /// [_maxMandatoryRePrompts].
  void _scheduleMandatoryRePrompt() {
    if (_mandatoryRePromptScheduled) return;
    if (_mandatoryRePrompts >= _maxMandatoryRePrompts) {
      debugPrint('[LeadX Update] mandatory prompt limit reached; '
          'leaving the app usable until the next check');
      return;
    }
    _mandatoryRePrompts++;
    _mandatoryRePromptScheduled = true;
    Future<void>.delayed(_mandatoryRePromptDelay, () {
      _mandatoryRePromptScheduled = false;
      if (!mounted) return;
      _onControllerChanged();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
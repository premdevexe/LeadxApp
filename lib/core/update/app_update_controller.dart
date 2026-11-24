import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'app_update_service.dart';
import 'update_model.dart';

/// Coordinates the in-app update flow: quiet checks that never block app
/// startup, a sensible repeat cadence, and a mandatory gate that comes back
/// until the user actually installs the release.
///
/// Strategy:
/// - one check right after the app comes up, then a quiet retry every
///   [checkInterval] so a release published after launch still surfaces;
/// - an **optional** prompt is shown once per release — if the user
///   dismissed it, it stays dismissed for that same build;
/// - a **mandatory** prompt is re-armed on every check. That is the whole
///   point of a force-update.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    Duration? checkInterval,
    Future<UpdateCheckResult?> Function()? checker,
    this.onUpdateAvailable,
  })  : _checkInterval = checkInterval ?? const Duration(hours: 4),
        _checker = checker ?? AppUpdateService.instance.checkForUpdate;

  /// How often to quietly re-check after the startup check.
  final Duration _checkInterval;
  final Future<UpdateCheckResult?> Function() _checker;
  final Future<void> Function(UpdateCheckResult result)? onUpdateAvailable;

  UpdateCheckResult? _result;
  int? _dismissedVersionCode;
  Timer? _timer;
  bool _stopped = false;
  bool _checking = false;

  /// The most recent portal response (may say "no update").
  UpdateCheckResult? get result => _result;

  bool get isChecking => _checking;

  /// True when the portal says an installable release is pending.
  bool get hasPendingUpdate => _result?.isActionable ?? false;

  /// True when the pending release is a force-update.
  bool get isMandatory => _result?.isMandatory ?? false;

  /// The build code the user last dismissed, if any.
  int? get dismissedVersionCode => _dismissedVersionCode;

  /// Starts the cadence: one immediate check, then the interval retries.
  ///
  /// Idempotent — a second call while the cadence is running does nothing.
  /// Safe to call again after [stop], which is what happens across a
  /// logout/login cycle.
  void start() {
    if (_disposed || _timer != null) return;
    _stopped = false;
    _runCheck();
    _timer = Timer.periodic(_checkInterval, (_) {
      if (_stopped) return;
      _runCheck();
    });
  }

  /// Pauses the cadence: cancels the interval timer and suppresses further
  /// notifications until [start] is called again.
  ///
  /// The gate calls this when it unmounts (the shell was replaced by the
  /// login screen), so a signed-out session stops polling the update portal.
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Runs a check now. Used by the startup cadence and by the manual
  /// "Check for updates" action.
  Future<UpdateCheckResult?> checkNow() async {
    await _runCheck();
    return _result;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }

  /// Publishes a change to listeners without ever touching the tree mid-build.
  ///
  /// Two hazards to dodge:
  /// - `notifyListeners` throws once the notifier is disposed, and this
  ///   controller outlives any single widget because the provider is
  ///   app-scoped;
  /// - listeners are `Provider` scopes, so notifying during a build (which is
  ///   exactly when [start] is called, from a post-frame callback right as
  ///   the shell mounts) triggers "setState() called during build". When a
  ///   frame is in progress the notification is deferred to after it.
  ///
  /// The scheduler is consulted only when a binding actually exists, so this
  /// stays usable from plain unit tests and any non-UI context.
  void _notify() {
    if (_disposed || _stopped) return;

    // `SchedulerBinding.instance` asserts when no binding exists, and there
    // is no null-safe accessor in this Flutter version — probe once and
    // remember, since binding presence can't change within a process.
    final hasScheduler = _schedulerChecked && _hasScheduler || _probeScheduler();
    if (hasScheduler &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed || _stopped) return;
        notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  bool _schedulerChecked = false;
  bool _hasScheduler = false;

  bool _probeScheduler() {
    _schedulerChecked = true;
    try {
      // Throws if no binding has been initialized yet.
      SchedulerBinding.instance;
      _hasScheduler = true;
    } catch (_) {
      _hasScheduler = false;
    }
    return _hasScheduler;
  }

  Future<void> _runCheck() async {
    if (_checking) return;
    _checking = true;
    _notify();
    try {
      final result = await _checker();
      if (_stopped) return;
      _result = result;
      if (result != null && !result.updateAvailable) {
        // The portal says there is nothing newer to install, so any APK
        // sitting in the cache is from a release the user has already
        // finished with (installed or abandoned). Drop it; a failed check
        // (`null`) must keep the cached copy, so a retry can still reuse it
        // instead of re-downloading.
        await AppUpdateService.instance.clearCache();
      }
      if (result != null && result.isActionable && shouldPrompt()) {
        try {
          await onUpdateAvailable?.call(result);
        } catch (e) {
          debugPrint('[LeadX Update] onUpdateAvailable error: $e');
        }
      }
    } catch (e) {
      debugPrint('[LeadX Update] check failed: $e');
    } finally {
      _checking = false;
      _notify();
    }
  }

  /// Records that the user postponed an optional prompt for this build, so
  /// the next quiet check doesn't raise it again.
  void dismissPrompt(int versionCode) {
    _dismissedVersionCode = versionCode;
  }

  /// True when the pending release should be surfaced to the user right now.
  bool shouldPrompt() {
    final r = _result;
    if (r == null || !r.isActionable) return false;
    // Mandatory updates always come back.
    if (r.isMandatory) return true;
    // Optional ones only until the user dismisses that exact build.
    return r.latestVersion?.versionCode != _dismissedVersionCode;
  }
}

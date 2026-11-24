import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../utils/native_feedback.dart';
import 'app_update_service.dart';
import 'update_model.dart';

/// Where an in-app update stands, surfaced as the dialog's primary state.
enum _Phase { ready, downloading, verifying, installing }

/// The LeadX update sheet: a solid Material dialog that is dismissable for
/// optional releases and modal-blocking for mandatory ones.
///
/// Flow — review the release, download with live progress (cancellable), let
/// the service verify the SHA-256, then hand the APK to Android's installer.
/// The dialog never installs anything by itself: the OS package-installer
/// prompt is the user's actual consent.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateCheckResult info;

  bool get _mandatory => info.isMandatory;

  /// Presents the sheet. Resolves to `true` once an install has been handed
  /// off, so callers can refresh or log as needed.
  static Future<bool> show(BuildContext context, UpdateCheckResult info) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !info.isMandatory,
      builder: (_) => UpdateDialog(info: info),
    );
    return result ?? false;
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.ready;
  double? _progress;
  String _progressLine = '';
  String? _error;
  CancelToken? _cancelToken;
  int _failedAttempts = 0;

  VersionDetails? get _version => widget.info.latestVersion;

  bool get _busy =>
      _phase == _Phase.downloading ||
      _phase == _Phase.verifying ||
      _phase == _Phase.installing;

  /// Mandatory releases may only be closed when nothing is in flight — and
  /// even then, only by dismissing the whole flow (there is no "Later").
  bool get _canDismiss => !widget._mandatory && !_busy;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    final version = _version;
    if (version == null || version.downloadUrl.isEmpty) return;

    NativeFeedback.medium();
    final token = CancelToken();
    setState(() {
      _cancelToken = token;
      _phase = _Phase.downloading;
      _progress = null;
      _progressLine = 'Preparing download…';
      _error = null;
    });

    final download = await AppUpdateService.instance.download(
      version: version,
      cancelToken: token,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          final knownTotal = total > 0 ? total : version.fileSizeBytes;
          _progress = knownTotal > 0
              ? (received / knownTotal).clamp(0.0, 1.0)
              : null;
          _progressLine = knownTotal > 0
              ? '${_megabytes(received)} of ${_megabytes(knownTotal)}'
              : _megabytes(received);
        });
      },
    );

    if (!mounted) return;

    if (!download.isSuccess) {
      setState(() {
        _phase = _Phase.ready;
        _progress = null;
        _error = download.error ?? 'The update could not be downloaded.';
        if (!download.cancelled) _failedAttempts++;
      });
      if (download.cancelled) return;
      NativeFeedback.error();
      return;
    }

    setState(() {
      _phase = _Phase.verifying;
      _progress = 1.0;
      _progressLine = 'Verifying security signature…';
    });

    setState(() => _phase = _Phase.installing);

    final install = await AppUpdateService.instance.install(download.file!);
    if (!mounted) return;

    if (!install.launched) {
      setState(() {
        _phase = _Phase.ready;
        _error = install.error ?? 'Android could not start the installer.';
        _failedAttempts++;
      });
      NativeFeedback.error();
      return;
    }

    // The installer is up — but it still *needs the APK on disk*: Android
    // resolves the content:// URI lazily when the user taps "Install", so
    // deleting the file here is what makes PackageInstaller fail with
    // "There's a problem with the app file". Keep it; the next download
    // (or a re-prompt reusing the verified copy) manages the file.
    Navigator.of(context).pop(true);
  }

  void _cancelDownload() {
    NativeFeedback.light();
    _cancelToken?.cancel();
    setState(() {
      _phase = _Phase.ready;
      _progress = null;
      _error = 'Download cancelled.';
    });
  }

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final version = _version;
    final mandatory = widget._mandatory;

    return PopScope(
      canPop: _canDismiss,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppColors.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, cs, version, mandatory),
                const SizedBox(height: AppColors.space4),
                Text(
                  widget.info.prompt.message,
                  style: AppTypography.secondary.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (version != null && version.releaseNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: AppColors.space4),
                  _releaseNotes(cs, version),
                ],
                const SizedBox(height: AppColors.space4),
                _metaRow(cs, version, mandatory),
                if (_error != null) ...[
                  const SizedBox(height: AppColors.space3),
                  _errorLine(cs),
                ],
                const SizedBox(height: AppColors.space5),
                if (_busy)
                  _progressBlock(cs)
                else
                  _actions(cs, mandatory),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────

  Widget _header(
    BuildContext context,
    ColorScheme cs,
    VersionDetails? version,
    bool mandatory,
  ) {
    final accent = mandatory
        ? (cs.brightness == Brightness.dark
            ? AppColors.dangerDark
            : AppColors.dangerLight)
        : cs.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
          child: Icon(
            mandatory ? Icons.priority_high_rounded : Icons.system_update_rounded,
            size: 24,
            color: accent,
          ),
        ),
        const SizedBox(width: AppColors.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.info.prompt.title,
                style: AppTypography.sectionTitle.copyWith(
                  fontSize: 17,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                version == null
                    ? 'LeadX update'
                    : 'Version ${version.versionName} · build ${version.versionCode}',
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (_canDismiss || (mandatory && !_busy))
          IconButton(
            tooltip: mandatory ? 'Close' : 'Later',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          ),
      ],
    );
  }

  Widget _releaseNotes(ColorScheme cs, VersionDetails version) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "WHAT'S NEW",
          style: AppTypography.caption.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: AppColors.space2),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 140),
          padding: const EdgeInsets.all(AppColors.space3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: SingleChildScrollView(
            child: Text(
              version.releaseNotes.trim(),
              style: AppTypography.secondary.copyWith(
                color: cs.onSurface,
                height: 1.5,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(ColorScheme cs, VersionDetails? version, bool mandatory) {
    return Row(
      children: [
        Icon(Icons.arrow_downward_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          version == null ? 'Size unknown' : version.readableSize,
          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        if (mandatory)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (cs.brightness == Brightness.dark
                      ? AppColors.dangerDark
                      : AppColors.dangerLight)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Text(
              'REQUIRED',
              style: AppTypography.caption.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: cs.brightness == Brightness.dark
                    ? AppColors.dangerDark
                    : AppColors.dangerLight,
              ),
            ),
          ),
      ],
    );
  }

  Widget _errorLine(ColorScheme cs) {
    final danger = cs.brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.dangerLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _error!,
            style: AppTypography.caption.copyWith(color: danger, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ── Progress ─────────────────────────────────────────────────────────

  Widget _progressBlock(ColorScheme cs) {
    final verifying = _phase == _Phase.verifying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                verifying
                    ? 'Verifying security signature…'
                    : _phase == _Phase.installing
                        ? 'Opening installer…'
                        : 'Downloading update…',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              _progressLine,
              style: AppTypography.caption.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppColors.space2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: verifying ? null : _progress,
            minHeight: 7,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        if (_phase == _Phase.downloading) ...[
          const SizedBox(height: AppColors.space3),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cancelDownload,
              child: const Text('Cancel download'),
            ),
          ),
        ],
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Widget _actions(ColorScheme cs, bool mandatory) {
    final hasRelease = _version?.downloadUrl.isNotEmpty ?? false;

    return Row(
      children: [
        if (!mandatory) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                NativeFeedback.light();
                Navigator.of(context).pop(false);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
              child: const Text('Later'),
            ),
          ),
          const SizedBox(width: AppColors.space3),
        ],
        Expanded(
          child: FilledButton(
            onPressed: hasRelease ? _startUpdate : null,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: Text(
              _failedAttempts > 0
                  ? 'Try again'
                  : (mandatory ? 'Update now' : 'Update'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
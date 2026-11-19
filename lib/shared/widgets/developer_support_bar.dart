import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/services/dev_support_service.dart';

/// The "Developer Support" section at the foot of the login screen.
///
/// The whole control is tappable, animates on press, and runs the
/// [DevSupportService] fallback chain:
///   1. default email app (`mailto:`), 2. Gmail web compose, 3. copy dialog.
/// A success snackbar confirms the launch; if nothing could be opened the
/// user is shown a professional dialog with a "Copy Email Address" action
/// that copies the address to the clipboard and confirms it.
///
/// [service] is injectable so the fallback flow is unit-testable without
/// touching `url_launcher`.
class DeveloperSupportBar extends StatefulWidget {
  const DeveloperSupportBar({super.key, this.service});

  final DevSupportService? service;

  @override
  State<DeveloperSupportBar> createState() => _DeveloperSupportBarState();
}

class _DeveloperSupportBarState extends State<DeveloperSupportBar>
    with SingleTickerProviderStateMixin {
  /// The support control is deliberately low-contrast (quiet), but it must
  /// read clearly on the white/silver glass screen. Neutral ink:
  /// neutral-400 at rest, neutral-600 when pressed.
  static const _ink = Color(0xFFA3A3A3);
  static const _inkPressed = Color(0xFF525252);

  DevSupportService get _service => widget.service ?? DevSupportService();
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _busy = false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    _press.forward();

    final outcome = await _service.openSupport();

    if (!mounted) return;
    _press.reverse();
    setState(() => _busy = false);

    switch (outcome) {
      case SupportLaunchOutcome.openedMailto:
      case SupportLaunchOutcome.openedBrowser:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Opening developer support…',
                textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case SupportLaunchOutcome.needsCopyFallback:
        _showCopyFallback();
    }
  }

  /// Step 3 of the fallback chain: no email app or browser was available, so
  /// offer to copy the address instead. This is the path that resolves the
  /// "No email apps found" Android failure.
  Future<void> _showCopyFallback() async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            side: const BorderSide(color: Color(0x1F171717)),
          ),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(24),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x0F171717),
                ),
                child: const Icon(Icons.support_agent_outlined,
                    color: AppColors.successLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Developer Support',
                  style: AppTypography.sectionTitle.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We could not open an email app or browser on this device. '
                'Copy the support address instead and send it from any app.',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF525252),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _service.supportEmail),
                );
                if (!dialogContext.mounted) return;
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Support email copied: ${_service.supportEmail}',
                          textAlign: TextAlign.center),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Copy Email Address',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Developer Support',
      child: AnimatedScale(
        scale: _press.value == 0.0 ? 1.0 : 0.96,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onTap,
            onTapDown: (_) => _press.forward(),
            onTapUp: (_) => _press.reverse(),
            onTapCancel: () => _press.reverse(),
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(
                  alpha: _press.value == 0.0 ? 0.0 : 0.06),
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent_outlined,
                      size: 18, color: _press.value == 0.0 ? _ink : _inkPressed),
                  const SizedBox(width: 7),
                  Text(
                    _busy ? 'Opening…' : 'Developer Support',
                    style: AppTypography.caption.copyWith(
                      color: _press.value == 0.0 ? _ink : _inkPressed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

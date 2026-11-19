import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../auth/auth_controller.dart';

/// Professional splash screen for LeadX.
/// A flat reveal on a solid near-black (#0A0A0A) surface: a neutral logo
/// disc, a single neutral hairline, and the wordmark + tagline in Inter.
/// Zero colored tints — the one accent is a neutral (#FAFAFA) hairline
/// and the uncoloured loading bar. The whole composition fades in over
/// 180ms (opacity only) and the fade is skipped entirely when reduced
/// motion is on. Session authentication is restored in the background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final void Function(bool isAuthenticated) onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _surface = Color(0xFF0A0A0A); // neutral-950

  late final AnimationController _controller;
  late final Animation<double> _reveal;

  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _reveal = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();

    // 1. Restore auth session
    try {
      final isAuth = await context.read<AuthController>().restore();
      _isAuthenticated = isAuth;
    } catch (_) {
      _isAuthenticated = false;
    }

    // 2. Hold for at least 2000ms for a deliberate, fluid experience
    final elapsed = DateTime.now().difference(startTime);
    const minSplashDuration = Duration(milliseconds: 2000);
    if (elapsed < minSplashDuration) {
      await Future.delayed(minSplashDuration - elapsed);
    }

    if (!mounted) return;

    if (_controller.value < 0.95) {
      await _controller.forward();
    }

    if (mounted) {
      widget.onFinished(_isAuthenticated);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: skip the fade-in entirely.
    final animationsOff = MediaQuery.disableAnimationsOf(context);

    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Logo: widescreen brand mark contain fit
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180, maxHeight: 60),
              child: Image.asset(
                'assets/images/leadx_logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 16),
            // Tagline.
            Text(
              'EMPLOYEE PORTAL & CLOSING ENGINE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: AppColors.brandDark.withValues(alpha: 0.65),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
              ),
            ),
            const Spacer(flex: 3),
            // Flickr loading animation:
            LoadingAnimationWidget.flickr(
              leftDotColor: const Color(0xFF0063DC),
              rightDotColor: const Color(0xFFFF0084),
              size: 36,
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );

    if (!animationsOff) {
      content = FadeTransition(opacity: _reveal, child: content);
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(child: content),
    );
  }
}

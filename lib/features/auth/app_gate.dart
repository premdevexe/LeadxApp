import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dashboard/home_shell.dart';
import '../splash/splash_screen.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

/// Decides whether to show the animated splash screen, login screen, or app shell.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (!_splashComplete) {
      return SplashScreen(
        onFinished: (isAuthenticated) {
          if (mounted) {
            setState(() => _splashComplete = true);
          }
        },
      );
    }

    // Authenticated users always get the solid HomeShell (liquid-glass
    // chrome is retired app-wide); the switcher still animates the
    // splash → login → home transitions.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: auth.isAuthenticated
          ? const HomeShell(key: ValueKey('home'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/update/update_gate.dart';
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

    // Both authenticated users (HomeShell) and unauthenticated users
    // (LoginScreen) are wrapped by UpdateGate so update checks run and prompt
    // regardless of auth state.
    return UpdateGate(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: auth.isAuthenticated
            ? const HomeShell(key: ValueKey('home'))
            : const LoginScreen(key: ValueKey('login')),
      ),
    );
  }
}

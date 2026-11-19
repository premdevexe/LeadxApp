import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/design/app_theme.dart';
import 'core/design/theme_controller.dart';
import 'core/services/app_config_service.dart';
import 'core/services/app_services.dart';
import 'features/auth/app_gate.dart';
import 'features/auth/auth_controller.dart';
import 'firebase_options.dart';
import 'shared/format.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final services = AppServices();
  final auth = AuthController(services);

  // 401 (revoked/expired token) anywhere in the app forces re-login.
  services.setUnauthorizedCallback(() => auth.invalidate());

  // Restore any persisted session before the gate shows, so a returning
  // user lands straight in the "signed in" state.
  await auth.restore();

  // Centralized app configuration (admin currency). Load the offline cache
  // first so every figure formats correctly even before the network call,
  // then refresh against the live admin setting.
  final appConfig = AppConfigService();
  await appConfig.loadCache();
  appConfig.addListener(() => Fmt.bindLiveCurrency(appConfig.currency));
  Fmt.bindLiveCurrency(appConfig.currency);
  appConfig.refresh();

  // Persisted light/dark/system appearance.
  final theme = await ThemeController.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<AppConfigService>.value(value: appConfig),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
      ],
      child: const LeadxApp(),
    ),
  );
}

class LeadxApp extends StatelessWidget {
  const LeadxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: 'LeadX Employee',
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Splash → (login | HomeShell: the drawer + bottom-bar app shell).
      home: const AppGate(),
    );
  }
}

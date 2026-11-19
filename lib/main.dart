import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/design/app_theme.dart';
import 'core/design/theme_controller.dart';
import 'core/services/app_config_service.dart';
import 'core/services/app_services.dart';
import 'core/services/biometric_service.dart';
import 'core/services/connectivity_service.dart';
import 'features/auth/app_gate.dart';
import 'features/auth/auth_controller.dart';
import 'firebase_options.dart';
import 'shared/format.dart';
import 'shared/widgets/offline_indicator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge transparent system navigation and status bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final services = AppServices();
  final auth = AuthController(services);

  // Initialize hardware biometrics & security preferences
  await BiometricService.shared.init();

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
        ChangeNotifierProvider<ConnectivityService>(create: (_) => ConnectivityService()),
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
    final isDark = theme.isDark(context);

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp(
        title: 'LeadX Employee',
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Splash → (login | HomeShell: the drawer + bottom-bar app shell).
        home: const OfflineBanner(child: AppGate()),
      ),
    );
  }
}

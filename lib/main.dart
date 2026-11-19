import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_kit/flutter_liquid_glass_kit.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:provider/provider.dart';
import 'package:veneer/veneer.dart';

import 'core/design/app_theme.dart';
import 'core/design/lead_glass.dart';
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

  // Pre-warm the Apple liquid-glass shader pipeline. Liquid-glass chrome is
  // retired app-wide (every surface now resolves its solid SaaS fallback), so
  // this is inert — kept only so the engine stays initialised and the
  // out-of-scope login screen's gated glass path would still render if the
  // gate were ever restored. Harmless no-op in practice.
  await lgw.LiquidGlassWidgets.initialize();

  final services = AppServices();
  final auth = AuthController(services);

  // 401 (revoked/expired token) anywhere in the app forces re-login.
  services.setUnauthorizedCallback(() => auth.invalidate());

  // Centralized app configuration (admin currency). Load the offline cache
  // first so every figure formats correctly even before the network call,
  // then refresh against the live admin setting.
  final appConfig = AppConfigService();
  await appConfig.loadCache();
  appConfig.addListener(() => Fmt.bindLiveCurrency(appConfig.currency));
  Fmt.bindLiveCurrency(appConfig.currency);
  appConfig.refresh();

  // Persisted theme mode + glass preference.
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

    // Liquid-glass chrome is retired app-wide: every surface now resolves
    // its solid SaaS fallback. `.wrap()` still installs the glass engine's
    // theme + brightness resolver so the out-of-scope login screen's gated
    // glass path stays functional if it is ever re-enabled, and the kit
    // route observer keeps transitions stable.
    return lgw.LiquidGlassWidgets.wrap(
      child: MaterialApp(
        title: 'LeadX Employee',
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // LeadX scroll behaviour: drops Android overscroll glow/stretch so
        // backdrop sampling stays stable behind kit glass surfaces.
        scrollBehavior: const LiquidGlassScrollBehavior(),
        navigatorObservers: [
          VeneerNavigatorObserver(),
          // Switches covered kit glass surfaces to Flutter rendering while a
          // route transition is in flight.
          LiquidGlassRouteObserver(),
        ],
        home: const LiquidGlassRoot(),
      ),
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
    );
  }
}

/// Provides the kit's app-wide baseline settings so any remaining bare
/// kit surfaces render with a valid config. All *chrome* (cards, buttons,
/// fields, nav bar, segment bars) now resolves its **solid SaaS fallback**
/// because `LeadGlass.enabled` is forced to `false`; this scope is inert
/// for chrome and only guards the out-of-scope bare kit widgets so they
/// never build without a settings baseline.
class LiquidGlassRoot extends StatelessWidget {
  const LiquidGlassRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSettingsScope(
      settings: LeadGlass.defaultSettings,
      child: const AppGate(),
    );
  }
}

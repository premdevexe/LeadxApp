import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/design/app_theme.dart';
import 'core/design/theme_controller.dart';
import 'core/network/push_service.dart';
import 'core/services/app_config_service.dart';
import 'core/services/app_services.dart';
import 'core/services/biometric_service.dart';
import 'core/services/connectivity_service.dart';
import 'features/auth/app_gate.dart';
import 'features/auth/auth_controller.dart';
import 'features/follow_ups/follow_up_detail_screen.dart';
import 'features/follow_ups/follow_ups_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/payments/payment_detail_screen.dart';
import 'features/payments/payments_screen.dart';
import 'firebase_options.dart';
import 'shared/format.dart';
import 'shared/widgets/offline_indicator.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void _handleNotificationNavigation(Map<String, dynamic> data) {
  final navState = appNavigatorKey.currentState;
  if (navState == null) return;

  final type = data['type']?.toString();
  final orderIdStr = data['order_id']?.toString();
  final paymentIdStr = data['payment_id']?.toString();
  final followUpIdStr = data['follow_up_id']?.toString();

  if (orderIdStr != null && int.tryParse(orderIdStr) != null) {
    navState.push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: int.parse(orderIdStr)),
      ),
    );
    return;
  }

  if (paymentIdStr != null && int.tryParse(paymentIdStr) != null) {
    navState.push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(paymentId: int.parse(paymentIdStr)),
      ),
    );
    return;
  }

  if (followUpIdStr != null && int.tryParse(followUpIdStr) != null) {
    navState.push(
      MaterialPageRoute(
        builder: (_) => FollowUpDetailScreen(followUpId: int.parse(followUpIdStr)),
      ),
    );
    return;
  }

  if (type == 'payment') {
    navState.push(
      MaterialPageRoute(
        builder: (_) => const PaymentsScreen(),
      ),
    );
    return;
  }

  if (type == 'follow_up') {
    navState.push(
      MaterialPageRoute(
        builder: (_) => const FollowUpsScreen(),
      ),
    );
    return;
  }

  navState.push(
    MaterialPageRoute(
      builder: (_) => const NotificationsScreen(),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge transparent system navigation and status bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler for FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final services = AppServices();
  final auth = AuthController(services);

  // Bind notification tap to deep link navigation
  services.bindNotificationTap(_handleNotificationNavigation);

  // Initialize hardware biometrics & security preferences
  await BiometricService.shared.init();

  // 401 (revoked/expired token) anywhere in the app forces re-login.
  services.setUnauthorizedCallback(() => auth.invalidate());

  // Restore any persisted session before the gate shows, so a returning
  // user lands straight in the "signed in" state.
  await auth.restore();

  // Bootstrap push notifications (channels, permissions, token registration)
  await services.bootstrapPush();

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
        navigatorKey: appNavigatorKey,
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

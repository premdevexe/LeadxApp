import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/design/app_theme.dart';
import 'core/design/theme_controller.dart';
import 'core/network/push_service.dart';
import 'core/services/app_config_service.dart';
import 'core/services/app_services.dart';
import 'core/services/biometric_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/update/app_update_controller.dart';
import 'core/update/update_dialog.dart';
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
import 'shared/widgets/app_snackbar.dart';
import 'shared/widgets/offline_indicator.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void _handleNotificationNavigation(Map<String, dynamic> data) {
  final navState = appNavigatorKey.currentState;
  if (navState == null) return;

  final type = data['type']?.toString();
  if (type == 'app_update') {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        final controller = navContext.read<AppUpdateController>();
        final res = controller.result;
        if (res != null && res.isActionable) {
          UpdateDialog.show(navContext, res);
        } else {
          controller.checkNow().then((latestRes) {
            if (latestRes != null && latestRes.isActionable && navContext.mounted) {
              UpdateDialog.show(navContext, latestRes);
            }
          });
        }
      }
    });
    return;
  }

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

  // Restore the persisted session in the background, not on the critical
  // path. Awaiting `GET /me` before `runApp` would leave a blank screen for
  // the whole round-trip; instead the splash paints immediately and the
  // SplashScreen gates on `restore()` itself, so the token is settled before
  // the shell shows.
  auth.restore();

  // Push setup (FCM channels, permissions, token registration) is likewise
  // not needed to paint a frame. `registerToken` can run its retry/backoff
  // for several seconds on a slow network, so it runs in the background and
  // never holds up the splash.
  services.bootstrapPush().catchError((Object _) {});

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

  // Setup app update controller with persistent notification alert hook
  final prefs = await SharedPreferences.getInstance();
  final lastNotifiedCode = prefs.getInt('last_notified_update_version_code');

  final updateController = AppUpdateController(
    lastNotifiedVersionCode: lastNotifiedCode,
    onUpdateAvailable: (result) async {
      final latest = result.latestVersion;
      if (latest != null) {
        final currentUserId = auth.me?.data.id;
        final userKey = currentUserId != null
            ? 'notified_update_${currentUserId}_${latest.versionCode}'
            : 'notified_update_v${latest.versionCode}';

        // Check if already notified for this version
        if (prefs.getBool(userKey) == true) {
          return;
        }

        final title = result.prompt.title.isNotEmpty
            ? result.prompt.title
            : 'Update Available: LeadX v${latest.versionName}';
        final message = result.prompt.message.isNotEmpty
            ? result.prompt.message
            : 'LeadX version ${latest.versionName} is ready. Tap to download and install.';

        final sent = await services.push.showUpdateNotification(
          title: title,
          body: message,
          versionCode: latest.versionCode,
          versionName: latest.versionName,
          userId: currentUserId,
        );

        if (sent) {
          await prefs.setBool(userKey, true);
          await prefs.setInt('last_notified_update_version_code', latest.versionCode);
        }
      }
    },
  );

  // Kicks off update check immediately on app start
  updateController.start();

  // Attach global scaffold messenger key to AppSnackBar
  AppSnackBar.messengerKey = appScaffoldMessengerKey;

  runApp(
    MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<AppConfigService>.value(value: appConfig),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<ConnectivityService>(create: (_) => ConnectivityService()),
        ChangeNotifierProvider<AppUpdateController>.value(value: updateController),
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
        scaffoldMessengerKey: appScaffoldMessengerKey,
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

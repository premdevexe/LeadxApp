import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/services.dart';

/// Top-level background message handler required by firebase_messaging.
/// Must be annotated with @pragma('vm:entry-point') so the background isolate
/// keeps it around.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint(
      'FCM background message received: ${message.messageId} - ${message.notification?.title}',
    );
  }

  // If this is a data-only payload arriving in the background, Android does not
  // display it in the system tray automatically. Post a local notification.
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ??
        message.data['header']?.toString();
    final body = message.data['body']?.toString() ??
        message.data['message']?.toString();
    if (title != null && title.isNotEmpty) {
      try {
        final local = FlutterLocalNotificationsPlugin();
        const androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await local.initialize(
          settings: const InitializationSettings(android: androidSettings),
        );
        await local.show(
          id: message.hashCode,
          title: title,
          body: body ?? '',
          payload: jsonEncode(message.data),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              AppConstants.fcmChannelId,
              'General',
              channelDescription: 'Order, payment and follow-up updates.',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      } catch (_) {}
    }
  }
}

/// Firebase Cloud Messaging for the employee app.
///
/// Splits responsibility cleanly across the two plugins:
/// - [FirebaseMessaging] owns the device token (register/refresh with Laravel,
///   scoped to the logged-in employee) and delivers background/terminated
///   messages through the OS tray.
/// - [FlutterLocalNotificationsPlugin] owns the Android notification channel
///   (Android 8+ requirement), shows the notification when a message arrives
///   while the app is in the FOREGROUND, and routes taps back to navigation.
///
/// Navigation hints (`type`, `order_id`, `order_number`, `action`) travel as
/// a JSON `payload` and surface through [onNotificationTapped].
class PushService {
  PushService(this.api);

  final LeadxApi api;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  int _nextId = 0;
  String? _lastRegisteredToken;
  bool _initialized = false;

  /// Fired on any notification tap (foreground-open, background-open, or
  /// terminated-start) with the backend's navigation `data`.
  void Function(Map<String, dynamic>)? onNotificationTapped;

  /// Idempotent. `main()` (via `bootstrapPush`) and `AuthController.login()`
  /// both call this; the one-time wiring below is guarded so the static FCM
  /// listeners (`onMessage`, `onMessageOpenedApp`, `onTokenRefresh`) are never
  /// attached twice — a second attach would deliver every push to
  /// [_showForeground] twice and re-fire token refresh.
  ///
  /// Call after `Firebase.initializeApp`.
  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;

      await _configureLocalNotifications();
      await requestPermission();

      // Terminated-app launch: the OS tray notification that started the app
      // carries its FCM data here.
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        onNotificationTapped?.call(initial.data);
      }

      // Check if launched by a local notification (e.g. app update notification tap)
      final launchDetails = await _local.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        final data = _decodePayload(payload);
        if (data != null) {
          onNotificationTapped?.call(data);
        }
      }

      // Foreground: show local notification so user sees it in system tray/heads-up
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Background: the OS shows the notification; tapping it brings the app to
      // the foreground and fires this.
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        onNotificationTapped?.call(msg.data);
      });

      // Subscribe to standard push topics so broadcast alerts reach this device
      try {
        await _fcm.subscribeToTopic('hello');
        await _fcm.subscribeToTopic('all');
        await _fcm.subscribeToTopic('general');
      } catch (e) {
        if (kDebugMode) debugPrint('Topic subscription failed: $e');
      }

      // FCM rotates tokens; re-register the new one, telling the server the old
      // value it replaces.
      _fcm.onTokenRefresh.listen((newToken) async {
        final oldToken = _lastRegisteredToken;
        if (oldToken != null && oldToken.isNotEmpty && oldToken != newToken) {
          try {
            await api.refreshDeviceToken(oldToken, newToken);
            _lastRegisteredToken = newToken;
          } on Object catch (e) {
            if (kDebugMode) debugPrint('FCM token refresh failed: $e');
          }
        } else {
          await registerToken();
        }
      });
    }

    // Register on every call: the post-login invocation is the one that binds
    // the token to the freshly-authenticated employee, so it must run even
    // after the one-time wiring above. Idempotent upsert server-side.
    await registerToken();
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      const general = AndroidNotificationChannel(
        AppConstants.fcmChannelId,
        'General',
        description: 'Order, payment and follow-up updates.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      const high = AndroidNotificationChannel(
        AppConstants.fcmHighPriorityChannelId,
        'High priority',
        description: 'Approval decisions and payment verifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      const updates = AndroidNotificationChannel(
        AppConstants.updateChannelId,
        'App Updates',
        description: 'New app updates and mandatory patch alerts.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await android.createNotificationChannel(general);
      await android.createNotificationChannel(high);
      await android.createNotificationChannel(updates);
    }
  }

  Future<void> requestPermission() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final android = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          await android.requestNotificationsPermission();
        }
      } else {
        await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification permission request error: $e');
    }
  }

  Future<String?> getToken() => _fcm.getToken();

  /// Register the current token with the backend for this employee.
  Future<void> registerToken({int retries = 2}) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final token = await _fcm.getToken();
        if (token == null || token.isEmpty) return;

        final platform = (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';
        final devName = await _deviceName();

        await api.registerDevice(
          token,
          platform: platform,
          deviceName: devName,
        );
        _lastRegisteredToken = token;
        if (kDebugMode) {
          debugPrint('FCM device registered: $token ($platform)');
        }
        return;
      } on Object catch (e) {
        if (kDebugMode) {
          debugPrint('FCM register attempt $attempt failed: $e');
        }
        if (attempt < retries) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
  }

  /// Subscribe the device to the employee's personal FCM topic.
  Future<void> subscribeEmployee(int employeeId) async {
    try {
      await _fcm.subscribeToTopic('user_$employeeId');
      if (kDebugMode) debugPrint('Subscribed to FCM topic: user_$employeeId');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to subscribe to user_$employeeId topic: $e');
    }
  }

  /// Unsubscribe from the employee's personal FCM topic.
  Future<void> unsubscribeEmployee(int employeeId) async {
    try {
      await _fcm.unsubscribeFromTopic('user_$employeeId');
      if (kDebugMode) debugPrint('Unsubscribed from FCM topic: user_$employeeId');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to unsubscribe from user_$employeeId topic: $e');
    }
  }

  /// Unregister the current device on logout.
  Future<void> unregister() async {
    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await api.unregisterDevice(token);
      _lastRegisteredToken = null;
    } on Object {
      if (kDebugMode) debugPrint('FCM unregister failed');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final data = message.data;
    final isHigh = (data['type'] ?? '') == 'closing_value' ||
        (data['type'] ?? '') == 'payment';

    final channelId = isHigh
        ? AppConstants.fcmHighPriorityChannelId
        : AppConstants.fcmChannelId;

    final channelName = isHigh ? 'High priority' : 'General';

    _nextId++;
    await _local.show(
      id: _nextId,
      title: message.notification?.title ?? data['title'] ?? AppConstants.appName,
      body: message.notification?.body ?? data['body'] ?? data['message'] ?? '',
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: isHigh
              ? 'Approval decisions and payment verifications.'
              : 'Order, payment and follow-up updates.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Displays a local notification in the notification shade informing the user that an update is available.
  /// Deduplicated so that each build/version is notified at most ONCE per user/device.
  Future<bool> showUpdateNotification({
    required String title,
    required String body,
    required int versionCode,
    required String versionName,
    int? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = userId != null ? 'notified_update_${userId}_$versionCode' : null;
      final deviceKey = 'notified_update_v$versionCode';

      // Ensure notification is only dispatched once per version per user/device
      if ((userKey != null && prefs.getBool(userKey) == true) ||
          prefs.getBool(deviceKey) == true) {
        if (kDebugMode) {
          debugPrint('[PushService] Update notification for version $versionCode already displayed. Suppressing duplicate.');
        }
        return false;
      }

      await _local.show(
        id: AppConstants.updateNotificationId,
        title: title,
        body: body,
        payload: jsonEncode({
          'type': 'app_update',
          'version_code': versionCode,
          'version_name': versionName,
        }),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.updateChannelId,
            'App Updates',
            channelDescription: 'New app updates and mandatory patch alerts.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      // Persist delivery so it never repeats for this version
      await prefs.setBool(deviceKey, true);
      if (userKey != null) {
        await prefs.setBool(userKey, true);
      }

      if (kDebugMode) {
        debugPrint('[PushService] Posted update notification: $title - $body');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushService] Failed to show update notification: $e');
      }
      return false;
    }
  }

  /// Tap on a local (foreground) notification.
  void _onLocalTap(NotificationResponse response) {
    final data = _decodePayload(response.payload);
    if (data != null) onNotificationTapped?.call(data);
  }

  Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return (jsonDecode(payload) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<String> _deviceName() async {
    final token = await _fcm.getToken();
    final suffix =
        (token != null && token.length >= 6) ? token.substring(0, 6) : 'dev';
    final os = (!kIsWeb && Platform.isIOS) ? 'iOS' : 'Android';
    return '$os Device $suffix';
  }
}

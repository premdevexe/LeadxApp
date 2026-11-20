import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  /// Fired on any notification tap (foreground-open, background-open, or
  /// terminated-start) with the backend's navigation `data`.
  void Function(Map<String, dynamic>)? onNotificationTapped;

  /// Call once on app start, after `Firebase.initializeApp`.
  Future<void> initialize() async {
    await _configureLocalNotifications();
    await requestPermission();

    // Terminated-app launch: the OS tray notification that started the app
    // carries its FCM data here.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      onNotificationTapped?.call(initial.data);
    }

    // Foreground: show local notification so user sees it in system tray/heads-up
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Background: the OS shows the notification; tapping it brings the app to
    // the foreground and fires this.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      onNotificationTapped?.call(msg.data);
    });

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

    // Try registering token on initialization
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
        importance: Importance.defaultImportance,
      );
      const high = AndroidNotificationChannel(
        AppConstants.fcmHighPriorityChannelId,
        'High priority',
        description: 'Approval decisions and payment verifications.',
        importance: Importance.high,
      );

      await android.createNotificationChannel(general);
      await android.createNotificationChannel(high);
    }
  }

  Future<void> requestPermission() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // On Android 13+ (API 33+), request notification runtime permission explicitly
      if (!kIsWeb && Platform.isAndroid) {
        final android = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          await android.requestNotificationsPermission();
        }
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await registerToken();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification permission request error: $e');
    }
  }

  Future<String?> getToken() => _fcm.getToken();

  /// Register the current token with the backend for this employee.
  Future<void> registerToken() async {
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
    } on Object catch (e) {
      // Not logged in / no network — the next login or token refresh retries.
      if (kDebugMode) debugPrint('FCM register failed (offline or unauthenticated): $e');
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
          importance: isHigh ? Importance.high : Importance.defaultImportance,
          priority: isHigh ? Priority.high : Priority.defaultPriority,
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

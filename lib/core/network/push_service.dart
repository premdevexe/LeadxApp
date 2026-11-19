import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/services.dart';

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
///
/// The service-account private key never lives in the app — only the public
/// client credentials in `google-services.json` do; all privileged sends are
/// server-side (Laravel `FcmService`).
class PushService {
  PushService(this.api);

  final LeadxApi api;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  int _nextId = 0;

  /// Fired on any notification tap (foreground-open, background-open, or
  /// terminated-start) with the backend's navigation `data`.
  void Function(Map<String, dynamic>)? onNotificationTapped;

  /// Call once on app start, after `Firebase.initializeApp`.
  Future<void> initialize() async {
    await _configureAndroid();
    await _requestPermission();

    // Terminated-app launch: the OS tray notification that started the app
    // carries its FCM data here.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      onNotificationTapped?.call(initial.data);
    }

    // Foreground: show our own local notification.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Background: the OS shows the notification; tapping it brings the app to
    // the foreground and fires this.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) =>
        onNotificationTapped?.call(msg.data));
  }

  Future<void> _configureAndroid() async {
    final android =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) {
      // Non-Android platform: nothing to configure.
      return;
    }

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

    await _local.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onLocalTap,
    );
    await android.createNotificationChannel(general);
    await android.createNotificationChannel(high);
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken();
    }
  }

  Future<String?> getToken() => _fcm.getToken();

  /// Register the current token with the backend for this employee.
  Future<void> _registerToken() async {
    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) return;

    try {
      await api.registerDevice(token,
          platform: 'android', deviceName: await _deviceName());
    } on Object {
      // Not logged in / no network — the next login or token refresh retries.
      if (kDebugMode) debugPrint('FCM register failed');
    }

    // FCM rotates tokens; re-register the new one, telling the server the old
    // value it replaces.
    _fcm.onTokenRefresh.listen((newToken) async {
      try {
        await api.refreshDeviceToken(token, newToken);
      } on Object {
        if (kDebugMode) debugPrint('FCM refresh failed');
      }
    });
  }

  /// Unregister the current device on logout.
  Future<void> unregister() async {
    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await api.unregisterDevice(token);
    } on Object {
      if (kDebugMode) debugPrint('FCM unregister failed');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final data = message.data;
    final channelId = (data['type'] ?? 'general') == 'closing_value'
        ? AppConstants.fcmHighPriorityChannelId
        : AppConstants.fcmChannelId;

    final channelName = channelId == AppConstants.fcmHighPriorityChannelId
        ? 'High priority'
        : 'General';

    _nextId++;
    await _local.show(
      id: _nextId,
      title: message.notification?.title ?? AppConstants.appName,
      body: message.notification?.body ?? '',
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName),
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
    return 'Employee device $suffix';
  }
}

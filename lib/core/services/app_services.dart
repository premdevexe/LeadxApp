import '../network/api_client.dart';
import '../network/push_service.dart';
import '../network/services.dart';
import '../realtime/reverb_service.dart';

/// Coordinates the app's long-lived services: the API client, FCM push, and
/// the Reverb real-time socket. One instance per app run.
class AppServices {
  ApiClient get apiClient => ApiClient.shared;
  late final LeadxApi api;
  late final PushService push;

  ReverbService? _reverb;

  /// The FCM tap-navigation handler (set by the UI layer).
  void Function(Map<String, dynamic>)? onNotificationTapped;

  /// Fired when real-time is unavailable and polling should take over.
  void Function(bool fallbackActive)? onRealtimeFallback;

  AppServices({LeadxApi? customApi, PushService? customPush}) {
    api = customApi ?? LeadxApi(apiClient);
    push = customPush ?? PushService(api);
  }

  /// Wire the 401 (token revoked/expired) handler used by the API client.
  void setUnauthorizedCallback(void Function() handler) {
    ApiClient.shared.setUnauthorizedCallback(handler);
  }

  /// Register where FCM/Reverb tap + fallback events should be routed.
  void bindNotificationTap(void Function(Map<String, dynamic>) handler) {
    onNotificationTapped = handler;
    push.onNotificationTapped = handler;
  }

  Future<void> bootstrapPush() async {
    await push.initialize();
    push.onNotificationTapped = onNotificationTapped;
  }

  void startSession(int employeeId) {
    _reverb?.disconnect();
    final service = ReverbService(
      api: api,
      employeeId: employeeId,
      onFallbackToPolling: onRealtimeFallback,
    );
    _reverb = service;
    service.connect().catchError((_) {
      onRealtimeFallback?.call(true);
      return null;
    });
  }

  void stopSession() {
    _reverb?.disconnect();
    _reverb = null;
  }

  ReverbService? get reverb => _reverb;

  void addReverbListener(void Function(RealtimeEvent) listener) {
    _reverb?.addEventListener(listener);
  }
}

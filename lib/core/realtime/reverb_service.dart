import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../core/network/services.dart';


/// Real-time transport for the LeadX employee app, speaking the Pusher
/// protocol that Laravel Reverb serves.
///
/// - One websocket per login session, subscribed to the employee's private
///   channel `user.{employeeId}.notifications` (the same channel the web
///   panel uses, so website <-> app stay in sync).
/// - Private-channel authorization is delegated to the backend
///   `POST /employee/broadcasting/auth` (Sanctum Bearer) — the app never
///   holds the Reverb signing secret.
/// - Reconnects with exponential backoff. When the socket cannot be
///   reached or authorized, [onFallbackToPolling] fires so the caller can
///   poll `GET /employee/notifications` instead (graceful degradation).
class ReverbService {
  ReverbService({required this.api, required this.employeeId, this.onFallbackToPolling});

  final LeadxApi api;
  final int employeeId;

  /// Called when the socket connection (or channel auth) fails so the UI
  /// can switch to polling; called again with `false` when it recovers.
  void Function(bool fallbackActive)? onFallbackToPolling;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  String? _socketId;
  String? get socketId => _socketId;
  bool _disposed = false;
  int _backoffTicks = 0;

  Completer<String>? _socketIdCompleter;
  Completer<void>? _subscribedCompleter;

  /// Live listeners; each event is delivered to all.
  final List<void Function(RealtimeEvent)> _listeners = [];

  void addEventListener(void Function(RealtimeEvent) listener) =>
      _listeners.add(listener);

  void removeEventListener(void Function(RealtimeEvent) listener) =>
      _listeners.remove(listener);

  String get _fullChannelName => 'private-user.$employeeId.notifications';

  bool get isConnected => _channel != null;

  /// Opens the websocket, completes the handshake, and subscribes to the
  /// employee's private channel.
  ///
  /// Throws [ApiException] when the server is unreachable or channel
  /// authorization is denied — callers should then start the polling
  /// fallback.
  Future<void> connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    final host = await ApiConfig.reverbHost();
    final port = await ApiConfig.reverbPort();
    final baseUrl = await ApiConfig.baseUrl();
    final isSecure = baseUrl.startsWith('https');
    final scheme = isSecure ? 'wss' : 'ws';
    final portPart = (isSecure && port == 443) || (!isSecure && port == 80) ? '' : ':$port';
    final uri = Uri.parse('$scheme://$host$portPart/app');

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    final socketIdC = Completer<String>();
    final subscribedC = Completer<void>();
    _socketIdCompleter = socketIdC;
    _subscribedCompleter = subscribedC;

    _sub = channel.stream.listen(
      _onData,
      onError: (_) {},
      onDone: _handleClosed,
    );

    // 1. Handshake frame (pusher:connected) carries the server socket id.
    final socketId =
        await socketIdC.future.timeout(const Duration(seconds: 10));
    _socketId = socketId;

    // 2. Ask the backend (our own Sanctum token) to sign the channel.
    final auth = await _authorizeChannel(socketId);

    // 3. Subscribe with the signed token.
    channel.sink.add(json.encode({
      'event': 'pusher:subscribe',
      'channel': _fullChannelName,
      'data': auth,
    }));

    // 4. Wait for confirmation.
    await subscribedC.future.timeout(const Duration(seconds: 10));

    _backoffTicks = 0;
    onFallbackToPolling?.call(false);
  }

  void _onData(dynamic raw) {
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final event = frame['event'] as String? ?? '';
    switch (event) {
      case 'pusher:connected':
        if (!_socketIdCompleter!.isCompleted) {
          _socketIdCompleter!.complete((frame['socket_id'] as String?) ?? '');
        }
        break;
      case 'pusher:subscribed':
        if (frame['channel'] == _fullChannelName &&
            !_subscribedCompleter!.isCompleted) {
          _subscribedCompleter!.complete();
        }
        break;
      case 'pusher:error':
        // Auth or subscription failure — treat as disconnected so the
        // reconnect / polling fallback kicks in.
        if (_subscribedCompleter != null && !_subscribedCompleter!.isCompleted) {
          _subscribedCompleter!.completeError(
              ApiException(statusCode: 403, message: 'Channel auth failed'));
        } else {
          _handleClosed();
        }
        break;
      case 'notification.received':
      case 'orders.updated':
      case 'calendar.updated':
      case 'dashboard.updated':
        _emit(RealtimeEvent.fromJson(frame));
        break;
    }
  }

  /// Ask the backend to sign our channel. Returns the raw `auth` value the
  /// socket layer expects. A 503 means the server has no real-time
  /// broadcaster configured (dev with BROADCAST_CONNECTION=log), which is
  /// a legitimate "no realtime here" answer.
  Future<String> _authorizeChannel(String socketId) async {
    try {
      final res =
          await api.authorizeBroadcastChannel(_fullChannelName, socketId);
      final auth = res['auth'];
      if (auth is String) return auth;
      throw ApiException(
          statusCode: 503,
          message: 'Real-time channel authorization unavailable on this server.');
    } on ApiException catch (e) {
      if (e.statusCode == 503) {
        // Keep the exception type but mark it non-retryable at a high level:
        // the caller catches and polls.
        rethrow;
      }
      rethrow;
    }
  }

  void _handleClosed() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _reconnect();
  }

  void _reconnect() {
    final delay =
        Duration(seconds: _backoffTicks >= 5 ? 30 : (1 << _backoffTicks) * 2);
    _backoffTicks++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      try {
        await connect();
      } catch (_) {
        onFallbackToPolling?.call(true);
      }
    });
  }

  void _emit(RealtimeEvent e) {
    for (final l in List.of(_listeners)) {
      l(e);
    }
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }
}

/// A normalized real-time frame.
class RealtimeEvent {
  final String type;
  final String? title;
  final String? message;
  final int? orderId;
  final String? orderNumber;
  final String? action;
  final String? createdAtIso;
  final Map<String, dynamic> raw;

  RealtimeEvent({
    required this.type,
    this.title,
    this.message,
    this.orderId,
    this.orderNumber,
    this.action,
    this.createdAtIso,
    required this.raw,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> frame) {
    final data =
        frame['data'] is Map<String, dynamic> ? frame['data'] as Map<String, dynamic> : frame;
    return RealtimeEvent(
      type: frame['type'] as String? ?? (frame['event'] as String? ?? 'general'),
      title: frame['title'] as String? ?? data['title'] as String?,
      message: frame['message'] as String? ?? data['message'] as String?,
      orderId: (frame['order_id'] as num?)?.toInt() ??
          (data['order_id'] as num?)?.toInt(),
      orderNumber:
          frame['order_number'] as String? ?? data['order_number'] as String?,
      action: frame['action'] as String? ?? data['action'] as String?,
      createdAtIso:
          frame['created_at_iso'] as String? ?? data['created_at_iso'] as String?,
      raw: data,
    );
  }
}

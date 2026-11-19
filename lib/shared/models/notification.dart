/// A database notification row (GET /employee/notifications).
/// The `data` blob is the serialized notification payload from the backend.
class AppNotification {
  final String id; // UUID
  final String type;
  final Map<String, dynamic> data;
  final String? readAt;
  final String? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        data: (json['data'] as Map<String, dynamic>?) ?? {},
        readAt: json['read_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  bool get isRead => readAt != null;

  /// Human-readable title. Notification classes store `title`/`message`
  /// inside the data blob where present; fall back to a cleaned type name.
  String get title {
    final t = data['title'];
    if (t is String && t.isNotEmpty) return t;
    final cls = type.split('.').last;
    return cls.isEmpty ? 'Notification' : cls;
  }

  String get message {
    final m = data['message'];
    return m is String ? m : '';
  }

  /// Navigation hint for tapping a notification (order detail etc.).
  int? get orderId => (data['order_id'] as num?)?.toInt();
  String? get orderNumber => data['order_number'] as String?;
  String get action => data['action'] as String? ?? 'general';
}

class NotificationsMeta {
  final int unreadCount;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  NotificationsMeta({
    required this.unreadCount,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory NotificationsMeta.fromJson(Map<String, dynamic> json) => NotificationsMeta(
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
        lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
        perPage: (json['per_page'] as num?)?.toInt() ?? 20,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

/// Mirrors `EmployeeCalendarEventResource` (personal calendar events).
class CalendarEvent {
  final int id;
  final String? googleEventId;
  final String summary;
  final String? description;
  final String? startAt;
  final String? endAt;
  final String status; // synced | error | deleted
  final String? lastSyncedAt;
  final String? createdAt;

  CalendarEvent({
    required this.id,
    this.googleEventId,
    required this.summary,
    this.description,
    this.startAt,
    this.endAt,
    required this.status,
    this.lastSyncedAt,
    this.createdAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: (json['id'] as num?)?.toInt() ?? 0,
        googleEventId: json['google_event_id'] as String?,
        summary: json['summary'] as String? ?? '',
        description: json['description'] as String?,
        startAt: json['start_at'] as String?,
        endAt: json['end_at'] as String?,
        status: json['status'] as String? ?? '',
        lastSyncedAt: json['last_synced_at'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

class CalendarConnection {
  final bool connected;
  final String? status;

  CalendarConnection({required this.connected, this.status});

  factory CalendarConnection.fromJson(Map<String, dynamic> json) => CalendarConnection(
        connected: json['connected'] == true,
        status: json['status'] as String?,
      );
}

/// GET /employee/calendar response.
class CalendarStatus {
  final CalendarConnection connection;
  final List<CalendarEvent> events;

  CalendarStatus({required this.connection, required this.events});

  factory CalendarStatus.fromJson(Map<String, dynamic> json) {
    final conn = (json['connection'] as Map<String, dynamic>?) ?? {};
    return CalendarStatus(
      connection: CalendarConnection.fromJson(conn),
      events: ((json['data'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CalendarEvent.fromJson)
          .toList(),
    );
  }
}

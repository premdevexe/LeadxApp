/// Mirrors `EmployeeGoogleConnectionResource` for the personal Google
/// Calendar OAuth integration (spec §10).
///
/// The backend deliberately never exposes tokens; only the user-visible
/// Google email + status fields are returned (defensively parsed here —
/// any of these may be absent, e.g. when no connection row exists yet).
class GoogleCalendarConnection {
  final bool connected;
  final String? status;
  final String? googleEmail;
  final String? connectedAt;
  final String? lastSyncedAt;

  const GoogleCalendarConnection({
    required this.connected,
    this.status,
    this.googleEmail,
    this.connectedAt,
    this.lastSyncedAt,
  });

  /// Parses a connection map. A `null`/absent map (no connection row) is
  /// a not-connected state with no detail fields.
  factory GoogleCalendarConnection.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return GoogleCalendarConnection(connected: false);
    }
    final raw = json['connected'];
    // The resource emits a real bool; fall back to the status string only
    // if the key is ever missing/changed.
    final connected = raw is bool
        ? raw
        : json['status'] == 'connected';
    return GoogleCalendarConnection(
      connected: connected,
      status: json['status'] as String?,
      googleEmail: json['google_email'] as String?,
      connectedAt: json['connected_at'] as String?,
      lastSyncedAt: json['last_synced_at'] as String?,
    );
  }
}

/// GET /employee/google/calendar response:
/// `{ data: { connected: bool, connection: GoogleCalendarConnection? } }`
class GoogleCalendarStatus {
  final bool connected;
  final GoogleCalendarConnection? connection;

  const GoogleCalendarStatus({required this.connected, this.connection});

  /// Effective connection detail — the top-level `connected` flag is the
  /// source of truth; `connection` carries the email + status when a row
  /// exists.
  GoogleCalendarConnection get effective =>
      connection ?? GoogleCalendarConnection(connected: connected);

  factory GoogleCalendarStatus.fromJson(Map<String, dynamic>? json) {
    final data = (json?['data'] as Map<String, dynamic>?) ?? const {};
    final connRaw = data['connection'];
    return GoogleCalendarStatus(
      connected: data['connected'] == true,
      connection: connRaw is Map
          ? GoogleCalendarConnection.fromJson(
              Map<String, dynamic>.from(connRaw))
          : null,
    );
  }
}

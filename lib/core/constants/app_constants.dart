/// API endpoint paths for the LeadX employee panel.
///
/// The backend is the single source of truth (Laravel, /api/v1). This file
/// only names the paths; it never holds credentials.
class ApiPaths {
  static const String login = '/employee/login';
  static const String logout = '/employee/logout';
  static const String me = '/employee/me';

  static const String dashboard = '/employee/dashboard';

  /// Admin-currency + formatting projection (single source of truth).
  static const String appConfig = '/employee/app-config';

  /// Employee self-analytics (module 12 mirror: KPI overview,
  /// product report rows, 6-month series).
  static const String analytics = '/employee/analytics';

  static const String orders = '/employee/orders';
  static String orderById(int id) => '/employee/orders/$id';
  static String orderComplete(int id) => '/employee/orders/$id/complete';
  static String orderResubmitClosing(int id) =>
      '/employee/orders/$id/closing-approval/resubmit';
  static String orderRevealApiKey(int id) => '/employee/orders/$id/api-key/reveal';
  static String orderWhatsappShare(int id) => '/employee/orders/$id/whatsapp-share';
  static String orderActivate(int id) => '/employee/orders/$id/activate';

  static const String products = '/products';

  static const String customers = '/employee/customers';
  static String customerById(int id) => '/employee/customers/$id';

  static const String payments = '/employee/payments';
  static String paymentById(int id) => '/employee/payments/$id';

  static const String subscriptions = '/employee/subscriptions';
  static const String subscriptionsExpiring = '/employee/subscriptions/expiring';
  static String subscriptionById(int id) => '/employee/subscriptions/$id';

  static const String followUps = '/employee/follow-ups';
  static String followUpById(int id) => '/employee/follow-ups/$id';

  static const String notifications = '/employee/notifications';
  static const String notificationsReadAll = '/employee/notifications/read-all';
  static String notificationRead(String id) => '/employee/notifications/$id/read';

  static const String calendar = '/employee/calendar';
  static const String calendarEvents = '/employee/calendar/events';
  static String calendarEventById(int id) => '/employee/calendar/events/$id';
  static const String calendarSync = '/employee/calendar/sync';
  static const String calendarConnect = '/employee/calendar/connect';

  /// Google Calendar OAuth integration (spec §10) — the employee's own
  /// personal Google account (GoogleCalendarController; team logins are
  /// rejected by the backend).
  static const String calendarStatus = '/employee/google/calendar';
  static const String calendarDisconnect =
      '/employee/google/calendar/disconnect';

  static const String profile = '/employee/profile';

  static const String customerIssues = '/employee/customer-issues';
  static String customerIssueById(int id) => '/employee/customer-issues/$id';

  static const String devices = '/employee/devices';
  static const String devicesRegister = '/employee/devices/register';
  static const String devicesUnregister = '/employee/devices/unregister';
  static const String devicesTokenRefresh = '/employee/devices/token-refresh';

  /// Reverb channel authorization (Bearer-token mirror of the web route).
  static const String broadcastingAuth = '/employee/broadcasting/auth';
}

class AppConstants {
  static const String appName = 'LeadX';
  static const String fcmChannelId = 'leadx_general';
  static const String fcmHighPriorityChannelId = 'leadx_high_priority';
  static const String updateChannelId = 'leadx_updates';
  static const int updateNotificationId = 999119;
}

import '../../core/constants/app_constants.dart';
import 'api_client.dart';

/// Thin repository over [ApiClient]. Each method mirrors one endpoint group
/// and returns the normalized body. Errors surface as [ApiException].
class LeadxApi {
  LeadxApi(this._client);
  final ApiClient _client;

  // ---- Auth ----
  Future<Map<String, dynamic>> login(String login, String password) async {
    final body = await _client.post(ApiPaths.login, data: {
      'login': login,
      'password': password,
    });
    return body;
  }

  Future<Map<String, dynamic>> logout() =>
      _client.post(ApiPaths.logout);

  Future<Map<String, dynamic>> me() => _client.get(ApiPaths.me);

  // ---- Dashboard ----
  Future<Map<String, dynamic>> dashboard({String view = 'my_data'}) =>
      _client.get(ApiPaths.dashboard, query: {'view': view});

  // ---- Analytics (employee self performance report) ----
  Future<Map<String, dynamic>> analytics({String? range}) =>
      _client.get(ApiPaths.analytics, query: {'range': ?range});

  // ---- App configuration (admin currency + formatting rules) ----
  Future<Map<String, dynamic>> appConfig() => _client.get(ApiPaths.appConfig);

  // ---- Orders ----
  Future<Map<String, dynamic>> orders({
    String view = 'my_data',
    int page = 1,
    int perPage = 20,
  }) =>
      _client.get(ApiPaths.orders,
          query: {'view': view, 'page': page, 'per_page': perPage});

  Future<Map<String, dynamic>> orderDetail(int id, {String view = 'my_data'}) =>
      _client.get(ApiPaths.orderById(id), query: {'view': view});

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload,
      {String? idempotencyKey}) =>
      _client.post(ApiPaths.orders, data: payload, idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> completeOrder(int id) =>
      _client.post(ApiPaths.orderComplete(id));

  Future<Map<String, dynamic>> resubmitClosing(int id, num closingValue,
          {String? notes}) =>
      _client.post(ApiPaths.orderResubmitClosing(id), data: {
        'closing_value': closingValue,
        if (notes != null && notes.isNotEmpty) 'resubmission_notes': notes,
      });

  Future<Map<String, dynamic>> revealApiKey(int id) =>
      _client.post(ApiPaths.orderRevealApiKey(id));

  Future<Map<String, dynamic>> whatsappShare(int id, {bool includeKey = false}) =>
      _client.get(ApiPaths.orderWhatsappShare(id),
          query: {'include_api_key': includeKey});

  Future<Map<String, dynamic>> activateOrder(int id) =>
      _client.post(ApiPaths.orderActivate(id));

  Future<Map<String, dynamic>> products() => _client.get(ApiPaths.products);

  // ---- Customers (read-only) ----
  Future<Map<String, dynamic>> customers({
    String view = 'my_data',
    int page = 1,
    int perPage = 20,
  }) =>
      _client.get(ApiPaths.customers,
          query: {'view': view, 'page': page, 'per_page': perPage});

  Future<Map<String, dynamic>> customerDetail(int id, {String view = 'my_data'}) =>
      _client.get(ApiPaths.customerById(id), query: {'view': view});

  /// Verified CRM customers usable by the follow-up / issue pickers.
  Future<Map<String, dynamic>> verifiedCustomers() =>
      _client.get('/customers/verified');

  // ---- Payments (read-only) ----
  Future<Map<String, dynamic>> payments({
    String view = 'my_data',
    int page = 1,
    int perPage = 20,
  }) =>
      _client.get(ApiPaths.payments,
          query: {'view': view, 'page': page, 'per_page': perPage});

  Future<Map<String, dynamic>> paymentDetail(int id, {String view = 'my_data'}) =>
      _client.get(ApiPaths.paymentById(id), query: {'view': view});

  // ---- Subscriptions (read-only) ----
  Future<Map<String, dynamic>> subscriptions({
    String view = 'my_data',
    String? status,
    int page = 1,
    int perPage = 20,
  }) =>
      _client.get(ApiPaths.subscriptions,
          query: {
            'view': view,
            'status': ?status,
            'page': page,
            'per_page': perPage,
          });

  Future<Map<String, dynamic>> expiringSubscriptions({
    String view = 'my_data',
    int page = 1,
    int perPage = 20,
  }) =>
      _client.get(ApiPaths.subscriptionsExpiring,
          query: {'view': view, 'page': page, 'per_page': perPage});

  Future<Map<String, dynamic>> subscriptionDetail(int id,
          {String view = 'my_data'}) =>
      _client.get(ApiPaths.subscriptionById(id), query: {'view': view});

  // ---- Follow-ups ----
  Future<Map<String, dynamic>> followUps({
    String? status,
    int? customerId,
    String? followUpType,
    int page = 1,
    int perPage = 20,
  }) =>
      _client.get(ApiPaths.followUps, query: {
        'status': ?status,
        'customer_id': ?customerId,
        'follow_up_type': ?followUpType,
        'page': page,
        'per_page': perPage,
      });

  Future<Map<String, dynamic>> followUpDetail(int id) =>
      _client.get(ApiPaths.followUpById(id));

  Future<Map<String, dynamic>> createFollowUp(Map<String, dynamic> payload) =>
      _client.post(ApiPaths.followUps, data: payload);

  Future<Map<String, dynamic>> updateFollowUp(
          int id, Map<String, dynamic> payload) =>
      _client.put(ApiPaths.followUpById(id), data: payload);

  Future<Map<String, dynamic>> deleteFollowUp(int id) =>
      _client.delete(ApiPaths.followUpById(id));

  // ---- Notifications ----
  Future<Map<String, dynamic>> notifications({int page = 1, int perPage = 20}) =>
      _client.get(ApiPaths.notifications,
          query: {'page': page, 'per_page': perPage});

  Future<Map<String, dynamic>> markNotificationRead(String id) =>
      _client.post(ApiPaths.notificationRead(id));

  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      _client.post(ApiPaths.notificationsReadAll);

  // ---- Calendar ----
  Future<Map<String, dynamic>> calendar() => _client.get(ApiPaths.calendar);

  Future<Map<String, dynamic>> createCalendarEvent(Map<String, dynamic> payload) =>
      _client.post(ApiPaths.calendarEvents, data: payload);

  Future<Map<String, dynamic>> updateCalendarEvent(int id, Map<String, dynamic> payload) =>
      _client.put(ApiPaths.calendarEventById(id), data: payload);

  Future<Map<String, dynamic>> deleteCalendarEvent(int id) =>
      _client.delete(ApiPaths.calendarEventById(id));

  Future<Map<String, dynamic>> syncCalendar() =>
      _client.post(ApiPaths.calendarSync);

  Future<Map<String, dynamic>> calendarConnectUrl() =>
      _client.get(ApiPaths.calendarConnect);

  /// Google Calendar OAuth integration (spec §10): connection status for
  /// the employee's personal Google account (never credentials/tokens).
  Future<Map<String, dynamic>> calendarStatus() =>
      _client.get(ApiPaths.calendarStatus);

  /// Revokes the personal Google account connection.
  Future<Map<String, dynamic>> calendarDisconnect() =>
      _client.post(ApiPaths.calendarDisconnect);

  // ---- Profile ----
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) =>
      _client.put(ApiPaths.profile, data: payload);

  // ---- Customer issues ----
  Future<Map<String, dynamic>> customerIssues({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 15,
  }) =>
      _client.get(ApiPaths.customerIssues, query: {
        if (search != null && search.isNotEmpty) 'search': search,
        'status': ?status,
        'date_from': ?dateFrom,
        'date_to': ?dateTo,
        'page': page,
        'per_page': perPage,
      });

  Future<Map<String, dynamic>> createCustomerIssue(Map<String, dynamic> payload) =>
      _client.post(ApiPaths.customerIssues, data: payload);

  Future<Map<String, dynamic>> customerIssueDetail(int id) =>
      _client.get(ApiPaths.customerIssueById(id));

  Future<Map<String, dynamic>> updateCustomerIssue(int id, Map<String, dynamic> payload) =>
      _client.put(ApiPaths.customerIssueById(id), data: payload);

  // ---- FCM device registration ----
  Future<Map<String, dynamic>> registerDevice(String fcmToken,
          {String platform = 'android', String? deviceName}) =>
      _client.post(ApiPaths.devicesRegister, data: {
        'fcm_token': fcmToken,
        'platform': platform,
        if (deviceName != null && deviceName.isNotEmpty) 'device_name': deviceName,
      });

  Future<Map<String, dynamic>> refreshDeviceToken(String oldToken, String newToken) =>
      _client.post(ApiPaths.devicesTokenRefresh,
          data: {'old_token': oldToken, 'new_token': newToken});

  Future<Map<String, dynamic>> unregisterDevice(String fcmToken) =>
      _client.delete(ApiPaths.devicesUnregister, data: {'fcm_token': fcmToken});

  // ---- Reverb channel authorization ----
  Future<Map<String, dynamic>> authorizeBroadcastChannel(
          String channelName, String socketId) =>
      _client.post(ApiPaths.broadcastingAuth,
          data: {'channel_name': channelName, 'socket_id': socketId});
}

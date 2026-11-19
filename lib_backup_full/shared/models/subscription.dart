import 'json_helpers.dart';

/// Mirrors `SubscriptionResource`.
class Subscription {
  final int id;
  final int orderId;
  final int? teamId;
  final int? customerId;
  final int? productId;
  final String? billingCycle;
  final String? planSnapshot;
  final double? priceSnapshot;
  final double? amountPaid;
  final String? renewalDate;
  final String status;
  final String? startedAt;
  final String? expiresAt;
  final String? orderNumber;
  final String? orderStatus;
  final String? customerName;

  Subscription({
    required this.id,
    required this.orderId,
    this.teamId,
    this.customerId,
    this.productId,
    this.billingCycle,
    this.planSnapshot,
    this.priceSnapshot,
    this.amountPaid,
    this.renewalDate,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.orderNumber,
    this.orderStatus,
    this.customerName,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return Subscription(
      id: intFromJson(json['id']) ?? 0,
      orderId: intFromJson(json['order_id']) ?? 0,
      teamId: intFromJson(json['team_id']),
      customerId: intFromJson(json['customer_id']),
      productId: intFromJson(json['product_id']),
      billingCycle: json['billing_cycle'] as String?,
      planSnapshot: json['plan_snapshot'] as String?,
      priceSnapshot: doubleFromJson(json['price_snapshot']),
      amountPaid: doubleFromJson(json['amount_paid']),
      renewalDate: json['renewal_date'] as String?,
      status: json['status'] as String? ?? '',
      startedAt: json['started_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      orderNumber: order?['order_number'] as String?,
      orderStatus: order?['order_status'] as String?,
      customerName: (order?['customer'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }
}

/// Shared `meta` block returned by every employee-panel list endpoint
/// (view scoping + pagination). `warning` is non-null when team_data
/// was silently downgraded to my_data.
class ListMeta {
  final String view;
  final String? warning;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  ListMeta({
    required this.view,
    this.warning,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory ListMeta.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const {};
    return ListMeta(
      view: m['view'] as String? ?? 'my_data',
      warning: m['warning'] as String?,
      currentPage: (m['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (m['last_page'] as num?)?.toInt() ?? 1,
      perPage: (m['per_page'] as num?)?.toInt() ?? 20,
      total: (m['total'] as num?)?.toInt() ?? 0,
    );
  }
}

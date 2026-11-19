import 'customer.dart';
import 'json_helpers.dart';
import 'order.dart';
import 'subscription.dart';

class DashboardSummary {
  final int totalOrders;
  final double closingValue;
  final double verifiedRevenue;
  final int customersCount;
  final int activeSubscriptions;
  final int pendingPaymentsCount;
  final double pendingAmount;
  final int expiringSubscriptions;
  final int followUps;
  final int monthlyOrders;
  final double monthlyClosingValue;

  DashboardSummary({
    required this.totalOrders,
    required this.closingValue,
    required this.verifiedRevenue,
    required this.customersCount,
    required this.activeSubscriptions,
    required this.pendingPaymentsCount,
    required this.pendingAmount,
    required this.expiringSubscriptions,
    required this.followUps,
    required this.monthlyOrders,
    required this.monthlyClosingValue,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        totalOrders: intFromJson(json['total_orders']) ?? 0,
        closingValue: doubleFromJson(json['closing_value']) ?? 0,
        verifiedRevenue: doubleFromJson(json['verified_revenue']) ?? 0,
        customersCount: intFromJson(json['customers_count']) ?? 0,
        activeSubscriptions: intFromJson(json['active_subscriptions']) ?? 0,
        pendingPaymentsCount: intFromJson(json['pending_payments_count']) ?? 0,
        pendingAmount: doubleFromJson(json['pending_amount']) ?? 0,
        expiringSubscriptions: intFromJson(json['expiring_subscriptions']) ?? 0,
        followUps: intFromJson(json['follow_ups']) ?? 0,
        monthlyOrders: intFromJson(json['monthly_orders']) ?? 0,
        monthlyClosingValue: doubleFromJson(json['monthly_closing_value']) ?? 0,
      );
}

class DashboardChartPoint {
  final String month;
  final int orders;
  final double closingValue;

  DashboardChartPoint({required this.month, required this.orders, required this.closingValue});

  factory DashboardChartPoint.fromJson(Map<String, dynamic> json) => DashboardChartPoint(
        month: json['month'] as String? ?? '',
        orders: intFromJson(json['orders']) ?? 0,
        closingValue: doubleFromJson(json['closing_value']) ?? 0,
      );
}

class DashboardRecentFollowUp {
  final int id;
  final String? title;
  final String? status;
  final String? scheduledAt;
  final String? priority;
  final Customer? customer;

  DashboardRecentFollowUp({
    required this.id,
    this.title,
    this.status,
    this.scheduledAt,
    this.priority,
    this.customer,
  });

  factory DashboardRecentFollowUp.fromJson(Map<String, dynamic> json) =>
      DashboardRecentFollowUp(
        id: intFromJson(json['id']) ?? 0,
        title: json['title'] as String?,
        status: json['status'] as String?,
        scheduledAt: json['scheduled_at'] as String?,
        priority: json['priority'] as String?,
        customer: json['customer'] is Map<String, dynamic>
            ? Customer.fromJson(json['customer'] as Map<String, dynamic>)
            : null,
      );
}

class DashboardRecentNotification {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final String? readAt;
  final String? createdAt;

  DashboardRecentNotification({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    this.createdAt,
  });

  factory DashboardRecentNotification.fromJson(Map<String, dynamic> json) =>
      DashboardRecentNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        data: (json['data'] as Map<String, dynamic>?) ?? {},
        readAt: json['read_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  String get title => data['title'] as String? ?? type.replaceAll(RegExp(r'\\App\\Notifications\\'), '');
  String get message => data['message'] as String? ?? '';
  bool get isRead => readAt != null;
}

/// GET /employee/dashboard — the full dashboard widget set.
class Dashboard {
  final String currencySymbol;
  final String view;
  final String? warning;
  final DashboardSummary summary;
  final List<Order> recentOrders;
  final List<DashboardRecentFollowUp> recentFollowUps;
  final List<Subscription> expiringSubscriptions;
  final List<DashboardRecentNotification> recentNotifications;
  final List<DashboardChartPoint> monthlySalesChart;

  Dashboard({
    required this.currencySymbol,
    required this.view,
    this.warning,
    required this.summary,
    required this.recentOrders,
    required this.recentFollowUps,
    required this.expiringSubscriptions,
    required this.recentNotifications,
    required this.monthlySalesChart,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map<String, dynamic>?) ?? {};
    final summary = (json['summary'] as Map<String, dynamic>?) ?? {};

    final List<dynamic> recentOrdersRaw = switch (json['recent_orders']) {
      final Map<String, dynamic> m => (m['data'] as List<dynamic>?) ?? const [],
      final List<dynamic> l => l,
      _ => const [],
    };

    final List<dynamic> expiringRaw = switch (json['expiring_subscriptions']) {
      final Map<String, dynamic> m => (m['data'] as List<dynamic>?) ?? const [],
      final List<dynamic> l => l,
      _ => const [],
    };

    final List<dynamic> followUpsRaw = switch (json['recent_follow_ups']) {
      final Map<String, dynamic> m => (m['data'] as List<dynamic>?) ?? const [],
      final List<dynamic> l => l,
      _ => const [],
    };
    List<dynamic> notificationsRaw = (json['recent_notifications'] as List<dynamic>?) ?? const [];
    List<dynamic> chartRaw = (json['monthly_sales_chart'] as List<dynamic>?) ?? const [];

    return Dashboard(
      currencySymbol: meta['currency_symbol'] as String? ?? '',
      view: meta['view'] as String? ?? 'my_data',
      warning: meta['warning'] as String?,
      summary: DashboardSummary.fromJson(summary),
      recentOrders: recentOrdersRaw.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList(),
      expiringSubscriptions:
          expiringRaw.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList(),
      recentFollowUps: followUpsRaw.map((e) => DashboardRecentFollowUp.fromJson(e as Map<String, dynamic>)).toList(),
      recentNotifications:
          notificationsRaw.map((e) => DashboardRecentNotification.fromJson(e as Map<String, dynamic>)).toList(),
      monthlySalesChart:
          chartRaw.map((e) => DashboardChartPoint.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

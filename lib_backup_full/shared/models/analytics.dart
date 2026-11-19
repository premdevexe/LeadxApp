import 'json_helpers.dart';

/// GET /employee/analytics — the employee's self performance report
/// (module 12 mirror of the admin web portal).
///
/// Money fields arrive **pre-formatted** from the backend (`Money::format`
/// — a plain decimal string like "1234.56"); render them verbatim, never
/// through `Fmt.money`.
class EmployeeAnalytics {
  final AnalyticsEmployee employee;
  final AnalyticsOverview overview;
  final List<AnalyticsProductRow> products;
  final List<AnalyticsMonthlyPoint> monthly;

  EmployeeAnalytics({
    required this.employee,
    required this.overview,
    required this.products,
    required this.monthly,
  });

  /// True when the report carries no activity at all (zero orders, empty
  /// series, no product rows) — the screen shows its empty state.
  bool get isEmpty =>
      overview.totalOrders == 0 &&
      monthly.every((p) => p.orders == 0 && p.revenueValue == 0);

  factory EmployeeAnalytics.fromJson(Map<String, dynamic> json) {
    final productsRaw = (json['products'] as List<dynamic>?) ?? const [];
    final monthlyRaw = (json['monthly'] as List<dynamic>?) ?? const [];
    return EmployeeAnalytics(
      employee: AnalyticsEmployee.fromJson(
          (json['employee'] as Map<String, dynamic>?) ?? const {}),
      overview: AnalyticsOverview.fromJson(
          (json['overview'] as Map<String, dynamic>?) ?? const {}),
      products: productsRaw
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsProductRow.fromJson)
          .toList(),
      monthly: monthlyRaw
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsMonthlyPoint.fromJson)
          .toList(),
    );
  }
}

class AnalyticsEmployee {
  final int id;
  final String username;
  final String name;
  final int? teamId;

  AnalyticsEmployee({
    required this.id,
    required this.username,
    required this.name,
    this.teamId,
  });

  factory AnalyticsEmployee.fromJson(Map<String, dynamic> json) =>
      AnalyticsEmployee(
        id: intFromJson(json['id']) ?? 0,
        username: json['username'] as String? ?? '',
        name: json['name'] as String? ?? '',
        teamId: intFromJson(json['team_id']),
      );
}

class AnalyticsOverview {
  final String verifiedRevenue;
  final int totalOrders;
  final int totalPayingCustomers;
  final int activeSubscriptions;
  final int expiredSubscriptions;
  final String pendingCollections;
  final String totalClosingValue;
  final String totalDiscounts;
  final String totalProductValue;
  final String totalRefunds;

  AnalyticsOverview({
    required this.verifiedRevenue,
    required this.totalOrders,
    required this.totalPayingCustomers,
    required this.activeSubscriptions,
    required this.expiredSubscriptions,
    required this.pendingCollections,
    required this.totalClosingValue,
    required this.totalDiscounts,
    required this.totalProductValue,
    required this.totalRefunds,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) =>
      AnalyticsOverview(
        verifiedRevenue: json['verified_revenue'] as String? ?? '0.00',
        totalOrders: intFromJson(json['total_orders']) ?? 0,
        totalPayingCustomers: intFromJson(json['total_paying_customers']) ?? 0,
        activeSubscriptions: intFromJson(json['active_subscriptions']) ?? 0,
        expiredSubscriptions:
            intFromJson(json['expired_subscriptions']) ?? 0,
        pendingCollections: json['pending_collections'] as String? ?? '0.00',
        totalClosingValue: json['total_closing_value'] as String? ?? '0.00',
        totalDiscounts: json['total_discounts'] as String? ?? '0.00',
        totalProductValue: json['total_product_value'] as String? ?? '0.00',
        totalRefunds: json['total_refunds'] as String? ?? '0.00',
      );
}

class AnalyticsMonthlyPoint {
  final String month;
  final String label;
  final String revenue;
  final int orders;
  final int subscriptions;

  AnalyticsMonthlyPoint({
    required this.month,
    required this.label,
    required this.revenue,
    required this.orders,
    required this.subscriptions,
  });

  factory AnalyticsMonthlyPoint.fromJson(Map<String, dynamic> json) =>
      AnalyticsMonthlyPoint(
        month: json['month'] as String? ?? '',
        label: json['label'] as String? ?? json['month'] as String? ?? '',
        revenue: json['revenue'] as String? ?? '0.00',
        orders: intFromJson(json['orders']) ?? 0,
        subscriptions: intFromJson(json['subscriptions']) ?? 0,
      );

  /// The pre-formatted revenue string reduced to a comparable number for
  /// bar heights. Lenient: strips everything except digits, a sign and the
  /// decimal point, so a locale/ symbol-prefixed string still scales.
  double get revenueValue {
    final cleaned =
        revenue.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}

/// One per-product report row (`SalesAnalyticsService::rowFor`).
///
/// Backend keys: `product_id` (null for "Uncataloged"), `product` (name),
/// `orders`, `collected_revenue`, `active_subscriptions`, `active_customers`,
/// `pending_collection`, `monthly_sales` (map of "YYYY-MM" →
/// {orders, revenue}).
class AnalyticsProductRow {
  final int? productId;
  final String name;
  final int orders;
  final String collectedRevenue;
  final int activeSubscriptions;
  final int activeCustomers;
  final String pendingCollection;

  AnalyticsProductRow({
    required this.productId,
    required this.name,
    required this.orders,
    required this.collectedRevenue,
    required this.activeSubscriptions,
    required this.activeCustomers,
    required this.pendingCollection,
  });

  factory AnalyticsProductRow.fromJson(Map<String, dynamic> json) {
    // The row label lives under `product`; tolerate a bare `name`/`product_name`
    // fallback if the report shape ever shifts.
    final name = json['product'] as String? ??
        json['product_name'] as String? ??
        json['name'] as String? ??
        'Uncataloged';
    return AnalyticsProductRow(
      productId: intFromJson(json['product_id']),
      name: name,
      orders: intFromJson(json['orders']) ?? 0,
      collectedRevenue: json['collected_revenue'] as String? ?? '0.00',
      activeSubscriptions: intFromJson(json['active_subscriptions']) ?? 0,
      activeCustomers: intFromJson(json['active_customers']) ?? 0,
      pendingCollection: json['pending_collection'] as String? ?? '0.00',
    );
  }

  /// Pre-formatted revenue as a comparable number (same lenient strip as
  /// [AnalyticsMonthlyPoint.revenueValue]).
  double get revenueValue =>
      double.tryParse(collectedRevenue.replaceAll(RegExp(r'[^0-9.\-]'), '')) ??
          0;
}

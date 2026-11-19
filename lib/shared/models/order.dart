import 'json_helpers.dart';

class OrderSubscription {
  final int id;
  final String? status;
  final String? billingCycle;
  final String? planSnapshot;
  final double? priceSnapshot;
  final String? expiresAt;

  OrderSubscription({
    required this.id,
    this.status,
    this.billingCycle,
    this.planSnapshot,
    this.priceSnapshot,
    this.expiresAt,
  });

  factory OrderSubscription.fromJson(Map<String, dynamic> json) => OrderSubscription(
        id: intFromJson(json['id']) ?? 0,
        status: json['status'] as String?,
        billingCycle: json['billing_cycle'] as String?,
        planSnapshot: json['plan_snapshot'] as String?,
        priceSnapshot: doubleFromJson(json['price_snapshot']),
        expiresAt: json['expires_at'] as String?,
      );
}

/// Mirrors `OrderResource` on the backend (frozen product snapshots included).
class Order {
  final int id;
  final String orderNumber;
  final int? teamId;
  final String? teamCodeSnapshot;
  final String? teamName;
  final int? assignedEmployeeId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int? productId;
  final String? productName;
  final String? productNameSnapshot;
  final double? productPriceSnapshot;
  final String? productDurationSnapshot;
  final String? duration;
  final double? productValue;
  final double? discountAmount;
  final double closingValue;
  final double? amountReceived;
  final String? paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String? closingValueStatus;
  final String? closingApprovalNotes;
  final double? minimumClosingPriceSnapshot;
  final String? assignedEmployeeName;
  final bool legacyFlag;
  final OrderSubscription? subscription;
  final String createdAt;
  final String updatedAt;

  Order({
    required this.id,
    required this.orderNumber,
    this.teamId,
    this.teamCodeSnapshot,
    this.teamName,
    this.assignedEmployeeId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.productId,
    this.productName,
    this.productNameSnapshot,
    this.productPriceSnapshot,
    this.productDurationSnapshot,
    this.duration,
    this.productValue,
    this.discountAmount,
    required this.closingValue,
    this.amountReceived,
    this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.closingValueStatus,
    this.closingApprovalNotes,
    this.minimumClosingPriceSnapshot,
    this.assignedEmployeeName,
    this.legacyFlag = false,
    this.subscription,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: intFromJson(json['id']) ?? 0,
        orderNumber: json['order_number'] as String? ?? '',
        teamId: intFromJson(json['team_id']),
        teamCodeSnapshot: json['team_code_snapshot'] as String?,
        teamName: json['team_name'] as String?,
        assignedEmployeeId: intFromJson(json['assigned_employee_id']),
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        customerEmail: json['customer_email'] as String?,
        productId: intFromJson(json['product_id']),
        productName: json['product_name'] as String?,
        productNameSnapshot: json['product_name_snapshot'] as String?,
        productPriceSnapshot: doubleFromJson(json['product_price_snapshot']),
        productDurationSnapshot: json['product_duration_snapshot'] as String?,
        duration: json['duration'] as String?,
        productValue: doubleFromJson(json['product_value']),
        discountAmount: doubleFromJson(json['discount_amount']),
        closingValue: doubleFromJson(json['closing_value']) ?? 0,
        amountReceived: doubleFromJson(json['amount_received']),
        paymentMethod: json['payment_method'] as String?,
        paymentStatus: json['payment_status'] as String? ?? '',
        orderStatus: json['order_status'] as String? ?? '',
        closingValueStatus: json['closing_value_status'] as String? ??
            json['closing_status'] as String?,
        closingApprovalNotes: json['closing_approval_notes'] as String?,
        minimumClosingPriceSnapshot:
            doubleFromJson(json['minimum_closing_price_snapshot']),
        assignedEmployeeName: json['assigned_employee'] is Map
            ? ((json['assigned_employee'] as Map)['name'] ??
                    (json['assigned_employee'] as Map)['username'])
                as String?
            : json['assigned_employee_name'] as String?,
        legacyFlag: json['legacy_flag'] == true,
        subscription: json['subscription'] is Map<String, dynamic>
            ? OrderSubscription.fromJson(
                json['subscription'] as Map<String, dynamic>)
            : null,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );
}

class Product {
  final int id;
  final String name;
  final double price;
  final double minimumClosingPrice;
  final String duration;
  final String? durationLabel;
  final bool apiKeyRequired;
  final String status;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.minimumClosingPrice = 0,
    required this.duration,
    this.durationLabel,
    required this.apiKeyRequired,
    required this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: intFromJson(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        price: doubleFromJson(json['price']) ?? 0,
        minimumClosingPrice: doubleFromJson(json['minimum_closing_price']) ?? 0,
        duration: json['duration'] as String? ?? '',
        durationLabel: json['duration_label'] as String?,
        apiKeyRequired: json['api_key_required'] == true,
        status: json['status'] as String? ?? '',
      );
}

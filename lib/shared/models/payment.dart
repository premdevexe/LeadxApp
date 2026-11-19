import 'json_helpers.dart';

/// Mirrors `PaymentResource`.
class Payment {
  final int id;
  final int orderId;
  final int? customerId;
  final String? paymentMethod;
  final String? transactionReference;
  final double amount;
  final String? currency;
  final String? paymentDate;
  final String paymentStatus;
  final String? source;
  final bool verified;
  final String? verifiedAt;
  final String? adminNotes;
  final String? createdAt;
  final String? orderNumber;

  Payment({
    required this.id,
    required this.orderId,
    this.customerId,
    this.paymentMethod,
    this.transactionReference,
    required this.amount,
    this.currency,
    this.paymentDate,
    required this.paymentStatus,
    this.source,
    required this.verified,
    this.verifiedAt,
    this.adminNotes,
    this.createdAt,
    this.orderNumber,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: intFromJson(json['id']) ?? 0,
        orderId: intFromJson(json['order_id']) ?? 0,
        customerId: intFromJson(json['customer_id']),
        paymentMethod: json['payment_method'] as String?,
        transactionReference: json['transaction_reference'] as String?,
        amount: doubleFromJson(json['amount']) ?? 0,
        currency: json['currency'] as String?,
        paymentDate: json['payment_date'] as String?,
        paymentStatus: json['payment_status'] as String? ?? '',
        source: json['source'] as String?,
        verified: json['verified'] == true,
        verifiedAt: json['verified_at'] as String?,
        adminNotes: json['admin_notes'] as String?,
        createdAt: json['created_at'] as String?,
        orderNumber: json['order'] is Map
            ? (json['order'] as Map)['order_number'] as String?
            : json['order_number'] as String?,
      );
}

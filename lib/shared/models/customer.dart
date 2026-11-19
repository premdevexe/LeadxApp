import 'json_helpers.dart';

/// Mirrors `CustomerResource` (CRM customer reachable via the employee's orders).
class Customer {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? status;
  final int? teamId;
  final int purchasesCount;
  final double totalPurchased;
  final String? lastPurchaseAt;

  Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.status,
    this.teamId,
    required this.purchasesCount,
    required this.totalPurchased,
    this.lastPurchaseAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: intFromJson(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String?,
        teamId: intFromJson(json['team_id']),
        purchasesCount: intFromJson(json['purchases_count']) ?? 0,
        totalPurchased: doubleFromJson(json['total_purchased']) ?? 0,
        lastPurchaseAt: json['last_purchase_at'] as String?,
      );
}

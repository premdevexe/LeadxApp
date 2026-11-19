class FollowUp {
  final int id;
  final int? customerId;
  final String? customerName;
  final int? teamId;
  final int? assignedEmployeeId;
  final String? title;
  final String? description;
  final String? followUpType;
  final String? scheduledAt;
  final String? completedAt;
  final String status;
  final String? outcome;
  final String? nextFollowUpAt;
  final String? priority;
  final int? orderId;
  final String? orderNumber;
  final String? calendarSyncStatus;
  final String? createdAt;
  final String? updatedAt;

  FollowUp({
    required this.id,
    this.customerId,
    this.customerName,
    this.teamId,
    this.assignedEmployeeId,
    this.title,
    this.description,
    this.followUpType,
    this.scheduledAt,
    this.completedAt,
    required this.status,
    this.outcome,
    this.nextFollowUpAt,
    this.priority,
    this.orderId,
    this.orderNumber,
    this.calendarSyncStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return FollowUp(
      id: (json['id'] as num?)?.toInt() ?? 0,
      customerId: (json['customer_id'] as num?)?.toInt(),
      customerName: (json['customer'] as Map<String, dynamic>?)?['name'] as String?,
      teamId: (json['team_id'] as num?)?.toInt(),
      assignedEmployeeId: (json['assigned_employee_id'] as num?)?.toInt(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      followUpType: json['follow_up_type'] as String?,
      scheduledAt: json['scheduled_at'] as String?,
      completedAt: json['completed_at'] as String?,
      status: json['status'] as String? ?? '',
      outcome: json['outcome'] as String?,
      nextFollowUpAt: json['next_follow_up_at'] as String?,
      priority: json['priority'] as String?,
      orderId: (json['order_id'] as num?)?.toInt(),
      orderNumber: order?['order_number'] as String?,
      calendarSyncStatus: json['calendar_sync_status'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// Body-driven update command: `{ action: complete|reschedule|cancel }`.
class FollowUpActionRequest {
  final String action;
  final String? outcome;
  final String? notes;
  final String? scheduledAt;
  final String? nextFollowUpAt;

  FollowUpActionRequest.complete({this.outcome, this.notes})
      : action = 'complete',
        scheduledAt = null,
        nextFollowUpAt = null;
  FollowUpActionRequest.reschedule({required this.scheduledAt, this.notes})
      : action = 'reschedule',
        outcome = null,
        nextFollowUpAt = null;
  FollowUpActionRequest.cancel({this.notes})
      : action = 'cancel',
        outcome = null,
        scheduledAt = null,
        nextFollowUpAt = null;

  Map<String, dynamic> toJson() => {
        'action': action,
        if (outcome != null) 'outcome': outcome,
        if (notes != null) 'notes': notes,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (nextFollowUpAt != null) 'next_follow_up_at': nextFollowUpAt,
      };
}

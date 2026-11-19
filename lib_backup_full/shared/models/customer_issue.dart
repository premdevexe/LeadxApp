class CustomerIssueHistory {
  final String? oldStatus;
  final String? newStatus;
  final String? updateNote;
  final String? createdAt;

  CustomerIssueHistory({this.oldStatus, this.newStatus, this.updateNote, this.createdAt});

  factory CustomerIssueHistory.fromJson(Map<String, dynamic> json) =>
      CustomerIssueHistory(
        oldStatus: json['old_status'] as String?,
        newStatus: json['new_status'] as String?,
        updateNote: json['update_note'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

/// Mirrors `CustomerIssueResource` (employee-reported CRM issues).
class CustomerIssue {
  final int id;
  final int employeeId;
  final int customerId;
  final String? customerName;
  final String issueTitle;
  final String? issueDescription;
  final String status;
  final String? issueDate;
  final List<CustomerIssueHistory> history;
  final String? createdAt;
  final String? updatedAt;

  CustomerIssue({
    required this.id,
    required this.employeeId,
    required this.customerId,
    this.customerName,
    required this.issueTitle,
    this.issueDescription,
    required this.status,
    this.issueDate,
    required this.history,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerIssue.fromJson(Map<String, dynamic> json) => CustomerIssue(
        id: (json['id'] as num?)?.toInt() ?? 0,
        employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
        customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
        customerName: (json['customer'] as Map<String, dynamic>?)?['name'] as String?,
        issueTitle: json['issue_title'] as String? ?? '',
        issueDescription: json['issue_description'] as String?,
        status: json['status'] as String? ?? '',
        issueDate: json['issue_date'] as String?,
        history: ((json['history'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(CustomerIssueHistory.fromJson)
            .toList(),
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}

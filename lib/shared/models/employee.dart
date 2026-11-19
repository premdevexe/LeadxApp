class TeamSummary {
  final int id;
  final String? teamCode;
  final String? teamName;

  TeamSummary({required this.id, this.teamCode, this.teamName});

  factory TeamSummary.fromJson(Map<String, dynamic> json) => TeamSummary(
        id: (json['id'] as num?)?.toInt() ?? 0,
        teamCode: json['team_code'] as String?,
        teamName: json['team_name'] as String?,
      );
}

/// The authenticated employee's identity (GET /employee/me, /employee/profile).
class Employee {
  final int id;
  final String name;
  final String? username;
  final String? email;
  final String? phone;
  final String? role;
  final String? status;
  final TeamSummary? team;

  Employee({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.phone,
    this.role,
    this.status,
    this.team,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final rawTeam = json['team'];
    final teamMap = rawTeam is Map
        ? rawTeam.map((k, v) => MapEntry(k.toString(), v))
        : null;
    return Employee(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      status: json['status'] as String?,
      team: teamMap != null ? TeamSummary.fromJson(teamMap) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'team': team == null
            ? null
            : {'id': team!.id, 'team_code': team!.teamCode, 'team_name': team!.teamName},
      };
}

/// Session bootstrap document: identity + data-access + permission flags.
class MeResponse {
  final Employee data;
  final bool hasTeamDataAccess;
  final Map<String, bool> permissions;

  MeResponse({required this.data, required this.hasTeamDataAccess, required this.permissions});

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final dataMap = rawData is Map
        ? rawData.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final rawPerms = json['permissions'];
    final permsMap = <String, bool>{};
    if (rawPerms is Map) {
      rawPerms.forEach((k, v) {
        permsMap[k.toString()] = v == true;
      });
    }
    return MeResponse(
      data: Employee.fromJson(dataMap),
      hasTeamDataAccess: json['has_team_data_access'] == true,
      permissions: permsMap,
    );
  }

  bool canViewOrders() => permissions['orders.view'] == true;
  bool canCreateOrders() => permissions['orders.create'] == true;
  bool canCompleteOrders() => permissions['orders.complete'] == true;
  bool canViewCustomers() => permissions['customers.view'] == true;
  bool canViewPayments() => permissions['payments.view'] == true;
  bool canViewSubscriptions() => permissions['subscriptions.view'] == true;
  bool canViewFollowUps() => permissions['follow_ups.view'] == true;
  bool canCreateFollowUps() => permissions['follow_ups.create'] == true;
  bool canEditFollowUps() => permissions['follow_ups.edit'] == true;
}

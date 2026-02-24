class Waiter {
  final int? id;
  final String name;
  final int type; // 0 = fixed, 1 = percentage
  final double value; // fixed amount or percent
  final String? pinCode;
  final int isActive;
  final List<String> permissions;

  Waiter({
    this.id,
    required this.name,
    required this.type,
    required this.value,
    this.pinCode,
    this.isActive = 1,
    this.permissions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'pin_code': pinCode,
      'is_active': isActive,
      'permissions': permissions.join(','),
    };
  }

  factory Waiter.fromMap(Map<String, dynamic> map) {
    return Waiter(
      id: map['id'],
      name: map['name'],
      type: map['type'] ?? 0,
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      pinCode: map['pin_code'],
      isActive: map['is_active'] ?? 1,
      permissions: _parsePermissions(map['permissions']),
    );
  }

  static List<String> _parsePermissions(dynamic perms) {
    if (perms == null) return [];
    if (perms is List) return perms.map((e) => e.toString()).toList();
    if (perms is String) {
      if (perms.isEmpty) return [];
      return perms.split(',').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}

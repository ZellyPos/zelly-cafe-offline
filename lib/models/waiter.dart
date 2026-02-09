class Waiter {
  final int? id;
  final String name;
  final int type; // 0 = fixed, 1 = percentage
  final double value; // fixed amount or percent
  final String? pinCode;
  final int isActive;

  Waiter({
    this.id,
    required this.name,
    required this.type,
    required this.value,
    this.pinCode,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'pin_code': pinCode,
      'is_active': isActive,
    };
  }

  factory Waiter.fromMap(Map<String, dynamic> map) {
    return Waiter(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      value: (map['value'] as num).toDouble(),
      pinCode: map['pin_code'],
      isActive: map['is_active'] ?? 1,
    );
  }
}

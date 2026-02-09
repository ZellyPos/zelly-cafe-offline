class Customer {
  final int? id;
  final String name;
  final String? phone;
  final double debt;
  final double credit;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.debt = 0,
    this.credit = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'debt': debt,
      'credit': credit,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      debt: (map['debt'] as num?)?.toDouble() ?? 0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

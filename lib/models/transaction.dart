class Transaction {
  final int? id;
  final int? customerId;
  final String type; // 'outlay', 'payment', 'expense_outlay'
  final double amount;
  final String? note;
  final DateTime createdAt;

  Transaction({
    this.id,
    this.customerId,
    required this.type,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'type': type,
      'amount': amount,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class WaiterPayment {
  final int? id;
  final int waiterId;
  final double amount;
  final String paidAt;
  final String? note;
  final String createdBy;

  WaiterPayment({
    this.id,
    required this.waiterId,
    required this.amount,
    required this.paidAt,
    this.note,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'waiter_id': waiterId,
    'amount': amount.toInt(),
    'paid_at': paidAt,
    'note': note,
    'created_by': createdBy,
  };

  factory WaiterPayment.fromMap(Map<String, dynamic> map) => WaiterPayment(
    id: map['id'] as int?,
    waiterId: map['waiter_id'] as int,
    amount: (map['amount'] as num).toDouble(),
    paidAt: map['paid_at'] as String,
    note: map['note'] as String?,
    createdBy: (map['created_by'] as String?) ?? '',
  );
}

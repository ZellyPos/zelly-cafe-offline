class OrderPayment {
  final int? id;
  final String orderId;
  final String paymentType; // 'cash', 'card', 'bonus', 'debt', 'transfer'
  final double amount;
  final String? note;
  final DateTime createdAt;
  final int isSynced;

  OrderPayment({
    this.id,
    required this.orderId,
    required this.paymentType,
    required this.amount,
    this.note,
    required this.createdAt,
    this.isSynced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'payment_type': paymentType,
      'amount': amount,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory OrderPayment.fromMap(Map<String, dynamic> map) {
    return OrderPayment(
      id: map['id'] as int?,
      orderId: map['order_id'] as String,
      paymentType: map['payment_type'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: map['is_synced'] as int? ?? 0,
    );
  }

  OrderPayment copyWith({
    int? id,
    String? orderId,
    String? paymentType,
    double? amount,
    Object? note = _sentinel,
    DateTime? createdAt,
    int? isSynced,
  }) {
    return OrderPayment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      paymentType: paymentType ?? this.paymentType,
      amount: amount ?? this.amount,
      note: note == _sentinel ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

const _sentinel = Object();

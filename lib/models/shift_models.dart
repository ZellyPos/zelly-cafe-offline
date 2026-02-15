/// Smena - Kassir ish vaqtini va kassa balansini kuzatish uchun model
class Shift {
  final int? id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int openedBy;
  final int? closedBy;
  final double openingCash; // Ochilishdagi naqd pul
  final double? countedCash; // Yopilishda sanalgan naqd pul
  final double? difference; // Farq (Kutilgan vs Sanalgan)
  final String? notes;
  final int status; // 0: Ochiq, 1: Yopilgan

  Shift({
    this.id,
    required this.openedAt,
    this.closedAt,
    required this.openedBy,
    this.closedBy,
    this.openingCash = 0,
    this.countedCash,
    this.difference,
    this.notes,
    this.status = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opened_by': openedBy,
      'closed_by': closedBy,
      'opening_cash': openingCash,
      'counted_cash': countedCash,
      'difference': difference,
      'notes': notes,
      'status': status,
    };
  }

  factory Shift.fromMap(Map<String, dynamic> map) {
    return Shift(
      id: map['id'],
      openedAt: DateTime.parse(map['opened_at']),
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'])
          : null,
      openedBy: map['opened_by'],
      closedBy: map['closed_by'],
      openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0.0,
      countedCash: (map['counted_cash'] as num?)?.toDouble(),
      difference: (map['difference'] as num?)?.toDouble(),
      notes: map['notes'],
      status: map['status'] ?? 0,
    );
  }

  Shift copyWith({
    int? id,
    DateTime? openedAt,
    DateTime? closedAt,
    int? openedBy,
    int? closedBy,
    double? openingCash,
    double? countedCash,
    double? difference,
    String? notes,
    int? status,
  }) {
    return Shift(
      id: id ?? this.id,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openedBy: openedBy ?? this.openedBy,
      closedBy: closedBy ?? this.closedBy,
      openingCash: openingCash ?? this.openingCash,
      countedCash: countedCash ?? this.countedCash,
      difference: difference ?? this.difference,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

/// Kassa harakatlari (Kirim/Chiqim) modeli
class CashMovement {
  final int? id;
  final int shiftId;
  final String type; // 'IN' yoki 'OUT'
  final double amount;
  final String? reason; // 'inkassatsiya', 'xarajat', 'almashtirish' va h.k.
  final String? note;
  final DateTime createdAt;
  final int createdBy;

  CashMovement({
    this.id,
    required this.shiftId,
    required this.type,
    required this.amount,
    this.reason,
    this.note,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shift_id': shiftId,
      'type': type,
      'amount': amount,
      'reason': reason,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  factory CashMovement.fromMap(Map<String, dynamic> map) {
    return CashMovement(
      id: map['id'],
      shiftId: map['shift_id'],
      type: map['type'],
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'],
      note: map['note'],
      createdAt: DateTime.parse(map['created_at']),
      createdBy: map['created_by'],
    );
  }
}

/// Smena yakuniy hisoboti uchun yordamchi model
class ShiftSummary {
  final double totalCashSales;
  final double totalCardSales;
  final double totalDebtSales;
  final double totalInMovements;
  final double totalOutMovements;
  final double expectedCashBalance;

  ShiftSummary({
    this.totalCashSales = 0,
    this.totalCardSales = 0,
    this.totalDebtSales = 0,
    this.totalInMovements = 0,
    this.totalOutMovements = 0,
    this.expectedCashBalance = 0,
  });
}

import 'dart:convert';

/// AuditLog - Tizimdagi muhim amallarni audit qilish uchun model
class AuditLog {
  final int? id;
  final int? userId; // Amalni bajargan foydalanuvchi
  final String action; // 'discount', 'void', 'refund', 'edit', 'delete'
  final String entity; // 'order', 'product', 'user'
  final String entityId;
  final Map<String, dynamic>? beforeJson; // O'zgarishdan oldingi holat
  final Map<String, dynamic>? afterJson; // O'zgarishdan keyingi holat
  final DateTime createdAt;

  AuditLog({
    this.id,
    this.userId,
    required this.action,
    required this.entity,
    required this.entityId,
    this.beforeJson,
    this.afterJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'before_json': beforeJson != null ? jsonEncode(beforeJson) : null,
      'after_json': afterJson != null ? jsonEncode(afterJson) : null,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'],
      userId: map['user_id'],
      action: map['action'],
      entity: map['entity'],
      entityId: map['entity_id'],
      beforeJson: map['before_json'] != null
          ? jsonDecode(map['before_json'])
          : null,
      afterJson: map['after_json'] != null
          ? jsonDecode(map['after_json'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

/// ApprovalResult - PIN orqali tasdiqlash jarayoni natijasi
class ApprovalResult {
  final bool isApproved;
  final int? approvedById;
  final String? reason;

  ApprovalResult({required this.isApproved, this.approvedById, this.reason});
}

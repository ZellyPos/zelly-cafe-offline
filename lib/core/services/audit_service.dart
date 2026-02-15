import '../database_helper.dart';
import '../../models/audit_models.dart';

/// AuditService - Tizimdagi barcha muhim amallarni markazlashgan holda qayd qilish uchun servis
class AuditService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static final AuditService instance = AuditService._internal();
  AuditService._internal();

  /// Muhim amalni audit logiga yozish
  Future<void> logAction({
    int? userId,
    required String action,
    required String entity,
    required String entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    try {
      final log = AuditLog(
        userId: userId,
        action: action,
        entity: entity,
        entityId: entityId,
        beforeJson: before,
        afterJson: after,
        createdAt: DateTime.now(),
      );

      final db = await _dbHelper.database;
      await db.insert('audit_logs', log.toMap());
    } catch (e) {
      // Audit logi xatolikka sabab bo'lmasligi kerak
      print('Audit log recording failed: $e');
    }
  }

  /// Ma'lum bir obyekt (entity) bo'yicha barcha o'zgarishlar tarixini olish
  Future<List<AuditLog>> getEntityHistory(
    String entity,
    String entityId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'audit_logs',
      where: 'entity = ? AND entity_id = ?',
      whereArgs: [entity, entityId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => AuditLog.fromMap(maps[i]));
  }
}

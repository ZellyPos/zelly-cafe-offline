import '../../core/database_helper.dart';

/// Saboy (olib ketish) buyurtmalari uchun ma'lumotlar qatlami (faqat o'qish).
class SaboyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Bugungi (`day_reset_time` sozlamasiga ko'ra) saboy buyurtmalarini
  /// ofitsiant nomi va mahsulot soni bilan qaytaradi (eng yangi birinchi).
  Future<List<Map<String, dynamic>>> getTodayOrders() async {
    final db = await _dbHelper.database;

    final dayStart = await _dbHelper.getDayStartTime();
    final dayEnd = dayStart.add(const Duration(days: 1));

    return db.rawQuery('''
        SELECT o.id, o.daily_number, o.grand_total, o.opened_at,
               o.status, o.waiter_id, w.name as waiter_name,
               COUNT(oi.id) as item_count
        FROM orders o
        LEFT JOIN waiters w ON o.waiter_id = w.id
        LEFT JOIN order_items oi ON oi.order_id = o.id
        WHERE o.order_type = 1
          AND o.opened_at >= ?
          AND o.opened_at < ?
        GROUP BY o.id
        ORDER BY o.opened_at DESC
      ''', [dayStart.toIso8601String(), dayEnd.toIso8601String()]);
  }
}

import '../../models/waiter.dart';
import 'base_repository.dart';

/// Ofitsiantlar va ular bilan bog'liq maosh/statistika so'rovlari uchun
/// ma'lumotlar qatlami.
class WaiterRepository extends BaseRepository<Waiter> {
  @override
  String get table => 'waiters';

  @override
  String get remotePath => '/waiters';

  @override
  Waiter fromMap(Map<String, dynamic> map) => Waiter.fromMap(map);

  @override
  Map<String, dynamic> toMap(Waiter item) => item.toMap();

  @override
  int? idOf(Waiter item) => item.id;

  /// Remote'da `permissions` — massiv, DB'da esa vergul bilan ajratilgan satr.
  @override
  Map<String, dynamic> sanitizeForLocal(Map<String, dynamic> remoteRow) {
    if (remoteRow['permissions'] is List) {
      remoteRow['permissions'] = (remoteRow['permissions'] as List).join(',');
    }
    return remoteRow;
  }

  /// PIN duplikatini tekshiradi. Mavjud bo'lsa xodim nomini qaytaradi.
  Future<String?> findPinDuplicate(
    String? pin, {
    required int? excludeId,
  }) async {
    if (pin == null || pin.isEmpty) return null;
    final db = await dbHelper.database;
    final rows = await db.query(
      'waiters',
      where: excludeId != null ? 'pin_code = ? AND id != ?' : 'pin_code = ?',
      whereArgs: excludeId != null ? [pin, excludeId] : [pin],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['name']?.toString() ?? 'Boshqa xodim';
  }

  /// Berilgan ofitsiantga tegishli buyurtmalar soni (o'chirish cheklovi uchun).
  Future<int> countOrdersForWaiter(int waiterId) async {
    final orders = await dbHelper.queryByColumn('orders', 'waiter_id', waiterId);
    return orders.length;
  }

  /// Ommaviy komissiya (tur + qiymat) yangilash. "Kassa" chetlab o'tiladi.
  Future<void> bulkUpdateCommission({
    required int type,
    required double value,
    int? onlyCurrentType,
  }) async {
    final db = await dbHelper.database;
    final where = onlyCurrentType != null
        ? "name != 'Kassa' AND type = $onlyCurrentType"
        : "name != 'Kassa'";
    await db.rawUpdate(
      'UPDATE waiters SET type = ?, value = ? WHERE $where',
      [type, value],
    );
  }

  /// Ommaviy ruxsatlar yangilash: [add] qo'shiladi, [remove] o'chiriladi.
  Future<void> bulkUpdatePermissions({
    required List<String> add,
    required List<String> remove,
    int? onlyCurrentType,
  }) async {
    final db = await dbHelper.database;
    final where = onlyCurrentType != null
        ? "name != 'Kassa' AND type = $onlyCurrentType"
        : "name != 'Kassa'";
    final rows = await db.rawQuery(
      'SELECT id, permissions FROM waiters WHERE $where',
    );
    final batch = db.batch();
    for (final row in rows) {
      final raw = (row['permissions'] as String?) ?? '';
      final perms = raw.isEmpty
          ? <String>[]
          : raw.split(',').where((s) => s.isNotEmpty).toList();
      for (final p in add) {
        if (!perms.contains(p)) perms.add(p);
      }
      perms.removeWhere((p) => remove.contains(p));
      batch.rawUpdate(
        'UPDATE waiters SET permissions = ? WHERE id = ?',
        [perms.join(','), row['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Ofitsiant profili: berilgan davr uchun sotuvlar, ishlab topilgan,
  /// to'langan va to'lanadigan summalar hamda buyurtma/to'lov ro'yxatlari.
  Future<Map<String, dynamic>> getWaiterProfileData(
    int waiterId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await dbHelper.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    // 1. Ofitsiant ma'lumoti (tur/qiymat)
    final waiterData = await db.query(
      'waiters',
      where: 'id = ?',
      whereArgs: [waiterId],
      limit: 1,
    );
    if (waiterData.isEmpty) return {};
    final type = waiterData.first['type'] as int;
    final value = (waiterData.first['value'] as num).toDouble();
    final isKassa = waiterData.first['name'] == 'Kassa';

    // 2. Buyurtmalar yig'indisi (faqat status=1)
    final ordersRes = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, SUM(grand_total) as total
      FROM orders
      WHERE waiter_id = ? AND status = 1 AND created_at BETWEEN ? AND ?
    ''',
      [waiterId, startStr, endStr],
    );

    final int orderCount = ordersRes.first['count'] as int? ?? 0;
    final double totalSales =
        (ordersRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Ishlab topilgan
    double earned = 0;
    if (!isKassa) {
      if (type == 1) {
        earned = totalSales * (value / 100); // Foiz
      } else {
        earned = orderCount * value; // Har buyurtma uchun belgilangan
      }
    }

    // 4. Davr ichida to'langan
    final paymentsRes = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM waiter_payments
      WHERE waiter_id = ? AND paid_at BETWEEN ? AND ?
    ''',
      [waiterId, startStr, endStr],
    );

    final double totalPaid =
        (paymentsRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 5. To'lanadigan
    double payable = earned - totalPaid;

    // 6. Buyurtmalar ro'yxati
    final orders = await db.query(
      'orders',
      where: 'waiter_id = ? AND status = 1 AND created_at BETWEEN ? AND ?',
      whereArgs: [waiterId, startStr, endStr],
      orderBy: 'created_at DESC',
      limit: 50,
    );

    // 7. To'lovlar ro'yxati
    final payments = await db.query(
      'waiter_payments',
      where: 'waiter_id = ? AND paid_at BETWEEN ? AND ?',
      whereArgs: [waiterId, startStr, endStr],
      orderBy: 'paid_at DESC',
    );

    return {
      'summary': {
        'order_count': orderCount,
        'total_sales': totalSales,
        'earned': earned,
        'paid': totalPaid,
        'payable': payable,
      },
      'orders': orders,
      'payments': payments,
    };
  }

  /// Barcha ofitsiantlar statistikasini (davr/smena bo'yicha) qaytaradi.
  Future<List<Map<String, dynamic>>> getAllWaitersStats({
    String? fromDate,
    String? toDate,
    int? shiftId,
  }) {
    return dbHelper.getAllWaitersStats(
      fromDate: fromDate,
      toDate: toDate,
      shiftId: shiftId,
    );
  }

  /// Ofitsiantning maosh to'lovlari tarixini qaytaradi.
  Future<List<Map<String, dynamic>>> getWaiterPaymentHistory(int waiterId) {
    return dbHelper.getWaiterPaymentHistory(waiterId);
  }

  /// Maosh to'lovini qo'shadi.
  Future<void> addWaiterPayment({
    required int waiterId,
    required num amount,
    String? note,
    required String createdBy,
  }) async {
    await dbHelper.insert('waiter_payments', {
      'waiter_id': waiterId,
      'amount': amount.toInt(),
      'paid_at': DateTime.now().toIso8601String(),
      'note': note,
      'created_by': createdBy,
    });
  }
}

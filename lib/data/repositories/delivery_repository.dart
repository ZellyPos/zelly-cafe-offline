import '../../core/database_helper.dart';
import '../../models/courier.dart';
import '../../models/delivery_zone.dart';
import '../../models/order.dart';

/// Yetkazib berish (kuryerlar, hududlar, yetkazish buyurtmalari) uchun
/// **lokal** ma'lumotlar qatlami.
///
/// Chop etish va Telegram xabarlari provider (orkestratsiya) darajasida qoladi.
class DeliveryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Kuryerlar ─────────────────────────────────────────────────────────

  Future<List<Courier>> getCouriers() async {
    final db = await _dbHelper.database;
    final rows = await db.query('couriers', orderBy: 'name ASC');
    return rows.map(Courier.fromMap).toList();
  }

  Future<void> addCourier(String name, String? phone) async {
    final db = await _dbHelper.database;
    await db.insert('couriers', {
      'name': name,
      'phone': phone,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateCourier(Courier c) async {
    final db = await _dbHelper.database;
    await db.update('couriers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCourier(int id) async {
    final db = await _dbHelper.database;
    await db.delete('couriers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setCourierActive(int courierId, bool isActive) async {
    final db = await _dbHelper.database;
    await db.update(
      'couriers',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [courierId],
    );
  }

  Future<List<Map<String, dynamic>>> getCourierStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.phone,
        COUNT(o.id) as deliveries,
        SUM(o.grand_total) as revenue,
        SUM(o.delivery_fee) as delivery_fees
      FROM couriers c
      LEFT JOIN orders o ON o.courier_id = c.id
        AND o.status = 1
        AND o.order_type = 2
        AND o.created_at BETWEEN ? AND ?
      GROUP BY c.id
      ORDER BY deliveries DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  // ── Hududlar ──────────────────────────────────────────────────────────

  Future<List<DeliveryZone>> getZones() async {
    final db = await _dbHelper.database;
    final rows = await db.query('delivery_zones', orderBy: 'name ASC');
    return rows.map(DeliveryZone.fromMap).toList();
  }

  Future<void> addZone(String name, double fee, String color) async {
    final db = await _dbHelper.database;
    await db.insert('delivery_zones', {
      'name': name,
      'fee': fee,
      'color': color,
      'is_active': 1,
    });
  }

  Future<void> updateZone(DeliveryZone z) async {
    final db = await _dbHelper.database;
    await db.update('delivery_zones', z.toMap(), where: 'id = ?', whereArgs: [z.id]);
  }

  Future<void> deleteZone(int id) async {
    final db = await _dbHelper.database;
    await db.delete('delivery_zones', where: 'id = ?', whereArgs: [id]);
  }

  // ── Telefon bo'yicha qidiruv ───────────────────────────────────────────

  /// Mijozlar va oxirgi yetkazish manzillarini telefon bo'yicha qidiradi
  /// (telefon bo'yicha dublikatlar olib tashlanadi).
  Future<List<Map<String, dynamic>>> lookupByPhone(String phone) async {
    if (phone.length < 3) return [];
    final db = await _dbHelper.database;

    final customers = await db.rawQuery('''
      SELECT name, phone, NULL as address
      FROM customers
      WHERE phone LIKE ?
      LIMIT 5
    ''', ['%$phone%']);

    final orders = await db.rawQuery('''
      SELECT customer_name as name, customer_phone as phone, delivery_address as address
      FROM orders
      WHERE order_type = 2 AND customer_phone LIKE ? AND delivery_address IS NOT NULL
      GROUP BY customer_phone
      ORDER BY created_at DESC
      LIMIT 5
    ''', ['%$phone%']);

    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in [...customers, ...orders]) {
      final p = row['phone'] as String? ?? '';
      if (!seen.contains(p)) {
        seen.add(p);
        result.add(Map<String, dynamic>.from(row));
      }
    }
    return result;
  }

  // ── Yetkazish buyurtmalari ─────────────────────────────────────────────

  /// Aktiv yetkazish buyurtmalarini (ochiq yoki tanlangan davrda yopilgan)
  /// mahsulot va kuryer ma'lumoti bilan qaytaradi.
  Future<List<Order>> getActiveOrders({
    DateTime? filterStart,
    DateTime? filterEnd,
  }) async {
    final db = await _dbHelper.database;

    final start = filterStart ?? await _dbHelper.getDayStartTime();
    final end = filterEnd ?? start.add(const Duration(days: 1));

    final rows = await db.rawQuery('''
      SELECT o.*, c.name as courier_name
      FROM orders o
      LEFT JOIN couriers c ON o.courier_id = c.id
      WHERE o.order_type = 2
        AND (o.status = 0 OR (o.status = 1 AND o.created_at BETWEEN ? AND ?))
      ORDER BY o.created_at DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final result = <Order>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      final orderId = map['id'] as String;
      final items = await _getOrderItems(orderId);
      result.add(Order.fromMap(map, items: items));
    }
    return result;
  }

  Future<List<OrderItem>> _getOrderItems(String orderId) async {
    final db = await _dbHelper.database;
    final itemRows = await db.rawQuery('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);
    return itemRows
        .map((r) => OrderItem.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> updateDeliveryStatus(String orderId, int status) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'delivery_status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Buyurtmaga kuryer biriktiradi va holatni "yo'lda" (2) qiladi.
  Future<void> assignCourier(String orderId, int courierId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'courier_id': courierId, 'delivery_status': 2},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> markDelivered(String orderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'delivery_status': 3},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Buyurtmani to'lov bilan yopadi va chop etish uchun to'liq [Order]ni
  /// qaytaradi. Buyurtma topilmasa `null`.
  Future<Order?> closeOrder(
    String orderId,
    String paymentType,
    double paidAmount,
  ) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final orderRows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orderRows.isEmpty) return null;

    final map = Map<String, dynamic>.from(orderRows.first);
    final grandT = (map['grand_total'] as num?)?.toDouble() ?? 0.0;
    final change = paidAmount > grandT ? paidAmount - grandT : 0.0;

    await db.update('orders', {
      'status': 1,
      'delivery_status': 3,
      'payment_type': paymentType,
      'paid_amount': paidAmount,
      'receipt_change': change,
      'closed_at': now.toIso8601String(),
    }, where: 'id = ?', whereArgs: [orderId]);

    final updatedMap = Map<String, dynamic>.from(
      (await db.query('orders', where: 'id = ?', whereArgs: [orderId])).first,
    );
    final items = await _getOrderItems(orderId);
    return Order.fromMap(updatedMap, items: items);
  }

  /// Kun uchun keyingi kunlik buyurtma raqamini hisoblaydi.
  Future<int> getNextDailyNumber() async {
    final db = await _dbHelper.database;
    final dayStart = await _dbHelper.getDayStartTime();
    final res = await db.rawQuery(
      'SELECT MAX(daily_number) as max_no FROM orders WHERE created_at >= ?',
      [dayStart.toIso8601String()],
    );
    return ((res.first['max_no'] as int?) ?? 0) + 1;
  }

  /// Yangi yetkazish buyurtmasini va uning qatorlarini saqlaydi.
  Future<void> createOrder(
    Map<String, dynamic> orderMap,
    List<Map<String, dynamic>> itemRows,
  ) async {
    final db = await _dbHelper.database;
    await db.insert('orders', orderMap);
    for (final row in itemRows) {
      await db.insert('order_items', row);
    }
  }
}

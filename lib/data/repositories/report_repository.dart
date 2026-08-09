import '../../core/database_helper.dart';

/// Hisobotlar (dashboard, buyurtmalar, mahsulot/ofitsiant/joy/stol kesimi,
/// Z-hisobot) uchun **lokal** ma'lumotlar qatlami — asosan agregatsiya
/// so'rovlari (faqat o'qish).
///
/// `client` rejimidagi remote (HTTP) yuklash provider darajasida qoladi.
class ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// To'langan buyurtmalar uchun vaqt + ixtiyoriy filtrlardan WHERE bandi va
  /// argumentlarini quradi. Argumentlar tartibi: start, end, [orderType],
  /// [locationId], [waiterId].
  _Where _paidWhere({
    required DateTime start,
    required DateTime end,
    int? orderType,
    int? locationId,
    int? waiterId,
  }) {
    final args = <dynamic>[start.toIso8601String(), end.toIso8601String()];
    var where = 'o.status = 1 AND o.created_at >= ? AND o.created_at < ?';
    if (orderType != null) {
      where += ' AND o.order_type = ?';
      args.add(orderType);
    }
    if (locationId != null) {
      where += ' AND o.location_id = ?';
      args.add(locationId);
    }
    if (waiterId != null) {
      where += ' AND o.waiter_id = ?';
      args.add(waiterId);
    }
    return _Where(where, args);
  }

  // ── Dashboard ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats({
    required DateTime start,
    required DateTime end,
    int? orderType,
    int? locationId,
    int? waiterId,
  }) async {
    final db = await _dbHelper.database;
    final w = _paidWhere(
      start: start,
      end: end,
      orderType: orderType,
      locationId: locationId,
      waiterId: waiterId,
    );
    final whereClause = w.clause;

    final orders = await db.rawQuery('''
      SELECT
        COUNT(*) as count,
        SUM(grand_total) as total,
        AVG(grand_total) as avg_check,
        SUM(CASE WHEN order_type = 0 THEN grand_total ELSE 0 END) as dine_in_total,
        SUM(CASE WHEN order_type = 1 THEN grand_total ELSE 0 END) as takeaway_total
      FROM orders o
      WHERE $whereClause
    ''', w.args);

    // To'lov turlari — order_payments jadvalidan
    final payRows = await db.rawQuery('''
      SELECT op.payment_type, SUM(op.amount) as total_sum
      FROM order_payments op
      JOIN orders o ON op.order_id = o.id
      WHERE $whereClause
      GROUP BY op.payment_type
    ''', List<dynamic>.from(w.args));
    final payMap = _dbHelper.buildPaymentMap(payRows);

    // Chegirma statistikasi — metrics uchun
    final orderDiscRows = await db.rawQuery('''
      SELECT
        COUNT(*) as discount_count,
        SUM(
          CASE
            WHEN discount_type = 'percent' THEN (food_total * discount_value / 100)
            WHEN discount_type = 'fixed'   THEN discount_value
            ELSE 0
          END
        ) as total_discount_amount
      FROM orders o
      WHERE $whereClause AND discount_value > 0
    ''', List<dynamic>.from(w.args));
    final itemDiscRows = await db.rawQuery('''
      SELECT SUM(oi.discount_amount) as total_discount_amount
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE $whereClause AND oi.discount_amount > 0
    ''', List<dynamic>.from(w.args));

    final orderDiscTotal =
        (orderDiscRows.first['total_discount_amount'] as num?)?.toDouble() ?? 0.0;
    final itemDiscTotal =
        (itemDiscRows.first['total_discount_amount'] as num?)?.toDouble() ?? 0.0;

    final metricsRow = Map<String, dynamic>.from(orders.first);
    metricsRow['cash_total'] = payMap['cash'];
    metricsRow['card_total'] = payMap['card'];
    metricsRow['terminal_total'] = payMap['terminal'];
    metricsRow['debt_total'] = payMap['debt'];
    metricsRow['bonus_total'] = payMap['bonus'];
    metricsRow['transfer_total'] = payMap['transfer'];
    metricsRow['order_discount_total'] = orderDiscTotal;
    metricsRow['item_discount_total'] = itemDiscTotal;
    metricsRow['total_discount'] = orderDiscTotal + itemDiscTotal;
    metricsRow['order_discount_count'] = orderDiscRows.first['discount_count'] ?? 0;

    final topQty = await db.rawQuery('''
      SELECT p.name, SUM(oi.qty) as qty
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id
      ORDER BY qty DESC
      LIMIT 5
    ''', List<dynamic>.from(w.args));

    final topRevenue = await db.rawQuery('''
      SELECT p.name, SUM(oi.qty * oi.price) as revenue
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id
      ORDER BY revenue DESC
      LIMIT 5
    ''', List<dynamic>.from(w.args));

    return {
      'metrics': metricsRow,
      'topQty': topQty,
      'topRevenue': topRevenue,
    };
  }

  // ── Buyurtmalar ro'yxati ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders({
    required DateTime start,
    required DateTime end,
    int? orderType,
    int? locationId,
    int? waiterId,
  }) async {
    final db = await _dbHelper.database;
    final w = _paidWhere(
      start: start,
      end: end,
      orderType: orderType,
      locationId: locationId,
      waiterId: waiterId,
    );
    return db.rawQuery('''
      SELECT o.*, l.name as location_name, t.name as table_name, w.name as waiter_name
      FROM orders o
      LEFT JOIN locations l ON o.location_id = l.id
      LEFT JOIN tables t ON o.table_id = t.id
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE ${w.clause}
      ORDER BY o.created_at DESC
    ''', w.args);
  }

  // ── Mahsulot statistikasi ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProductStats({
    required DateTime start,
    required DateTime end,
    int? orderType,
    int? locationId,
    int? waiterId,
  }) async {
    final db = await _dbHelper.database;
    final w = _paidWhere(
      start: start,
      end: end,
      orderType: orderType,
      locationId: locationId,
      waiterId: waiterId,
    );
    return db.rawQuery('''
      SELECT
        p.name as name,
        p.category as category,
        SUM(oi.qty) as total_qty,
        SUM(oi.qty * oi.price) as total_revenue,
        p.quantity as current_stock
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE ${w.clause}
      GROUP BY p.id, p.name, p.quantity
      ORDER BY total_revenue DESC
    ''', w.args);
  }

  // ── Ofitsiant statistikasi ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWaiterStats({
    required DateTime start,
    required DateTime end,
    int? orderType,
    int? locationId,
  }) async {
    final db = await _dbHelper.database;
    final w = _paidWhere(
      start: start,
      end: end,
      orderType: orderType,
      locationId: locationId,
    );
    return db.rawQuery('''
      SELECT
        w.name as name,
        w.type as waiter_type,
        w.value as waiter_value,
        COUNT(o.id) as order_count,
        SUM(COALESCE(o.grand_total, 0)) as total_sales
      FROM waiters w
      LEFT JOIN orders o ON w.id = o.waiter_id AND ${w.clause}
      GROUP BY w.id, w.name, w.type, w.value
      HAVING order_count > 0
    ''', w.args);
  }

  // ── Joy statistikasi ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocationStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbHelper.database;
    final w = _paidWhere(start: start, end: end);
    return db.rawQuery('''
      SELECT
        l.name,
        COUNT(o.id) as order_count,
        SUM(o.grand_total) as total_revenue
      FROM locations l
      JOIN orders o ON l.id = o.location_id
      WHERE ${w.clause}
      GROUP BY l.id
      ORDER BY total_revenue DESC
    ''', w.args);
  }

  // ── Stol statistikasi ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTableStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbHelper.database;
    final w = _paidWhere(start: start, end: end);
    return db.rawQuery('''
      SELECT
        t.name as table_name,
        l.name as location_name,
        COUNT(o.id) as order_count,
        SUM(o.grand_total) as total_revenue
      FROM tables t
      JOIN locations l ON t.location_id = l.id
      JOIN orders o ON t.id = o.table_id
      WHERE ${w.clause}
      GROUP BY t.id
      ORDER BY total_revenue DESC
    ''', w.args);
  }

  // ── Z-hisobot ───────────────────────────────────────────────────────────

  /// Z-hisobot ma'lumotlari: `{summary, waiters, categories}`.
  /// Sana yorlig'i provider darajasida qo'shiladi.
  Future<Map<String, dynamic>> getZReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;
    final start = startDate.toIso8601String();
    final end = endDate.toIso8601String();

    final summaryRaw = await db.rawQuery('''
      SELECT
        COUNT(*) as count,
        SUM(grand_total) as total,
        MIN(created_at) as first_order,
        MAX(created_at) as last_order
      FROM orders
      WHERE status = 1 AND created_at >= ? AND created_at <= ?
    ''', [start, end]);

    // To'lov turlari — order_payments jadvalidan
    final zPayRows = await db.rawQuery('''
      SELECT op.payment_type, SUM(op.amount) as total_sum
      FROM order_payments op
      JOIN orders o ON op.order_id = o.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at <= ?
      GROUP BY op.payment_type
    ''', [start, end]);
    final zPayMap = _dbHelper.buildPaymentMap(zPayRows);

    // Chegirma statistikasi
    final discStats = await _dbHelper.getDiscountStatsByDateRange(start, end);

    final summaryRow = Map<String, dynamic>.from(summaryRaw.first);
    summaryRow['cash_total'] = zPayMap['cash'];
    summaryRow['card_total'] = zPayMap['card'];
    summaryRow['terminal_total'] = zPayMap['terminal'];
    summaryRow['debt_total'] = zPayMap['debt'];
    summaryRow['bonus_total'] = zPayMap['bonus'];
    summaryRow['transfer_total'] = zPayMap['transfer'];
    summaryRow['order_discount_total'] = discStats['order_discount_total'];
    summaryRow['item_discount_total'] = discStats['item_discount_total'];
    summaryRow['total_discount'] = discStats['total_discount'];
    summaryRow['order_discount_count'] = discStats['order_discount_count'];

    final waiterSales = await db.rawQuery('''
      SELECT COALESCE(w.name, 'Admin/Saboy') as name, SUM(o.grand_total) as sales
      FROM orders o
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at <= ?
      GROUP BY o.waiter_id
    ''', [start, end]);

    final categorySales = await db.rawQuery('''
      SELECT p.category, SUM(oi.qty) as qty, SUM(oi.qty * oi.price) as total
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at <= ?
      GROUP BY p.category
      ORDER BY total DESC
    ''', [start, end]);

    return {
      'summary': summaryRow,
      'waiters': waiterSales,
      'categories': categorySales,
    };
  }

  // ── Buyurtma tafsilotlari ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT o.*, l.name as location_name, t.name as table_name, w.name as waiter_name
      FROM orders o
      LEFT JOIN locations l ON o.location_id = l.id
      LEFT JOIN tables t ON o.table_id = t.id
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE o.id = ?
    ''', [orderId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);
  }
}

/// WHERE bandi va uning argumentlari.
class _Where {
  final String clause;
  final List<dynamic> args;
  const _Where(this.clause, this.args);
}

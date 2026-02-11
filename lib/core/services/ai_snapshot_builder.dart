import '../database_helper.dart';
import '../../models/ai_snapshot.dart';

class AiSnapshotBuilder {
  static Future<AiSnapshot> build({
    DateTime? from,
    DateTime? to,
    int? waiterId,
    int? locationId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final fromStr = from?.toIso8601String();
    final toStr = to?.toIso8601String();

    String where = "status = 0"; // Closed orders
    List<dynamic> whereArgs = [];

    if (fromStr != null) {
      where += " AND created_at >= ?";
      whereArgs.add(fromStr);
    }
    if (toStr != null) {
      where += " AND created_at <= ?";
      whereArgs.add(toStr);
    }
    if (waiterId != null) {
      where += " AND waiter_id = ?";
      whereArgs.add(waiterId);
    }
    if (locationId != null) {
      where += " AND location_id = ?";
      whereArgs.add(locationId);
    }

    // 1. Totals
    final totalsRes = await db.rawQuery('''
      SELECT 
        COUNT(*) as orders_count,
        SUM(grand_total) as total_revenue,
        AVG(grand_total) as avg_check
      FROM orders
      WHERE $where
    ''', whereArgs);

    final Map<String, dynamic> totals = {
      'orders_count': totalsRes.first['orders_count'] ?? 0,
      'total_revenue': totalsRes.first['total_revenue'] ?? 0.0,
      'avg_check': totalsRes.first['avg_check'] ?? 0.0,
    };

    // 2. Payment Split
    final paymentRes = await db.rawQuery('''
      SELECT payment_type, SUM(grand_total) as revenue
      FROM orders
      WHERE $where
      GROUP BY payment_type
    ''', whereArgs);

    final Map<String, double> paymentSplit = {};
    for (var row in paymentRes) {
      paymentSplit[row['payment_type'] as String] = (row['revenue'] as num)
          .toDouble();
    }

    // 3. Order Type Split
    final typeRes = await db.rawQuery('''
      SELECT order_type, COUNT(*) as count
      FROM orders
      WHERE $where
      GROUP BY order_type
    ''', whereArgs);

    final Map<String, int> orderTypeSplit = {};
    for (var row in typeRes) {
      // 0 = stol, 1 = saboy (assumed based on implementation)
      final label = row['order_type'] == 0 ? 'stol' : 'saboy';
      orderTypeSplit[label] = row['count'] as int;
    }

    // 4. Products Analysis
    // Join orders and order_items
    final productsRes = await db.rawQuery('''
      SELECT 
        p.name,
        SUM(oi.qty) as total_qty,
        SUM(oi.qty * oi.price) as total_revenue
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN products p ON p.id = oi.product_id
      WHERE o.$where
      GROUP BY p.id
      ORDER BY total_qty DESC
    ''', whereArgs);

    final List<Map<String, dynamic>> allProducts = productsRes
        .map(
          (e) => {
            'name': e['name'],
            'qty': e['total_qty'],
            'revenue': e['total_revenue'],
          },
        )
        .toList();

    final topProductsQty = allProducts.take(10).toList();

    final revenueSorted = List<Map<String, dynamic>>.from(allProducts)
      ..sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
    final topProductsRevenue = revenueSorted.take(10).toList();

    final bottomProducts = List<Map<String, dynamic>>.from(allProducts)
      ..sort((a, b) => (a['qty'] as num).compareTo(b['qty'] as num));
    final bottomThree = bottomProducts.take(5).toList();

    // 5. By Waiter
    final waiterRes = await db.rawQuery('''
      SELECT 
        w.name,
        COUNT(o.id) as orders,
        SUM(o.grand_total) as revenue,
        SUM(o.service_total) as service
      FROM orders o
      JOIN waiters w ON w.id = o.waiter_id
      WHERE o.$where
      GROUP BY w.id
    ''', whereArgs);

    final byWaiter = waiterRes
        .map(
          (e) => {
            'name': e['name'],
            'orders': e['orders'],
            'revenue': e['revenue'],
            'service': e['service'],
          },
        )
        .toList();

    // 6. By Location
    final locationRes = await db.rawQuery('''
      SELECT 
        l.name,
        COUNT(o.id) as orders,
        SUM(o.grand_total) as revenue
      FROM orders o
      JOIN locations l ON l.id = o.location_id
      WHERE o.$where
      GROUP BY l.id
    ''', whereArgs);

    final byLocation = locationRes
        .map(
          (e) => {
            'name': e['name'],
            'orders': e['orders'],
            'revenue': e['revenue'],
          },
        )
        .toList();

    return AiSnapshot(
      period: "${fromStr ?? 'start'} to ${toStr ?? 'now'}",
      totals: totals,
      paymentSplit: paymentSplit,
      orderTypeSplit: orderTypeSplit,
      topProductsQty: topProductsQty,
      topProductsRevenue: topProductsRevenue,
      bottomProducts: bottomThree,
      byWaiter: byWaiter,
      byLocation: byLocation,
    );
  }
}

import 'package:flutter/material.dart';
import '../core/database_helper.dart';

class ReportFilter {
  DateTime startDate;
  DateTime endDate;
  int? orderType; // 0=Dine-in, 1=Takeaway, null=All
  int? locationId;
  int? waiterId;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    this.orderType,
    this.locationId,
    this.waiterId,
  });
}

class ReportProvider extends ChangeNotifier {
  ReportFilter _filter = ReportFilter(
    startDate: DateTime.now().subtract(const Duration(days: 7)),
    endDate: DateTime.now(),
  );

  ReportFilter get filter => _filter;
  DateTime get dateFrom => _filter.startDate;
  DateTime get dateTo => _filter.endDate;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void updateFilter({
    DateTime? startDate,
    DateTime? endDate,
    int? orderType,
    int? locationId,
    int? waiterId,
    bool clearOrderType = false,
    bool clearLocation = false,
    bool clearWaiter = false,
  }) {
    if (startDate != null) _filter.startDate = startDate;
    if (endDate != null) _filter.endDate = endDate;

    if (clearOrderType)
      _filter.orderType = null;
    else if (orderType != null)
      _filter.orderType = orderType;

    if (clearLocation)
      _filter.locationId = null;
    else if (locationId != null)
      _filter.locationId = locationId;

    if (clearWaiter)
      _filter.waiterId = null;
    else if (waiterId != null)
      _filter.waiterId = waiterId;

    notifyListeners();
  }

  // Dashboard Aggregates
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    String whereClause =
        "o.status = 1 AND date(o.created_at) BETWEEN date(?) AND date(?)";
    List<dynamic> whereArgs = [start, end];

    if (_filter.orderType != null) {
      whereClause += " AND o.order_type = ?";
      whereArgs.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      whereClause += " AND o.location_id = ?";
      whereArgs.add(_filter.locationId);
    }
    if (_filter.waiterId != null) {
      whereClause += " AND o.waiter_id = ?";
      whereArgs.add(_filter.waiterId);
    }

    final orders = await db.rawQuery('''
      SELECT 
        COUNT(*) as count, 
        SUM(total) as total,
        AVG(total) as avg_check,
        SUM(CASE WHEN payment_type = 'Cash' OR payment_type = 'Naqd' THEN total ELSE 0 END) as cash_total,
        SUM(CASE WHEN payment_type = 'Card' OR payment_type = 'Karta' THEN total ELSE 0 END) as card_total,
        SUM(CASE WHEN payment_type = 'Terminal' THEN total ELSE 0 END) as terminal_total,
        SUM(CASE WHEN order_type = 0 THEN total ELSE 0 END) as dine_in_total,
        SUM(CASE WHEN order_type = 1 THEN total ELSE 0 END) as takeaway_total
      FROM orders o
      WHERE $whereClause
    ''', whereArgs);

    final topQty = await db.rawQuery('''
      SELECT p.name, SUM(oi.qty) as qty
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id
      ORDER BY qty DESC
      LIMIT 5
    ''', whereArgs);

    final topRevenue = await db.rawQuery('''
      SELECT p.name, SUM(oi.qty * oi.price) as revenue
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id
      ORDER BY revenue DESC
      LIMIT 5
    ''', whereArgs);

    return {
      'metrics': orders.first,
      'topQty': topQty,
      'topRevenue': topRevenue,
    };
  }

  // Filtered Orders List
  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    String whereClause = "date(o.created_at) BETWEEN date(?) AND date(?)";
    List<dynamic> whereArgs = [start, end];

    if (_filter.orderType != null) {
      whereClause += " AND o.order_type = ?";
      whereArgs.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      whereClause += " AND o.location_id = ?";
      whereArgs.add(_filter.locationId);
    }
    if (_filter.waiterId != null) {
      whereClause += " AND o.waiter_id = ?";
      whereArgs.add(_filter.waiterId);
    }

    return await db.rawQuery('''
      SELECT o.*, l.name as location_name, t.name as table_name, w.name as waiter_name
      FROM orders o
      LEFT JOIN locations l ON o.location_id = l.id
      LEFT JOIN tables t ON o.table_id = t.id
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE $whereClause
      ORDER BY o.created_at DESC
    ''', whereArgs);
  }

  // Product Performance Stats
  Future<List<Map<String, dynamic>>> getProductStats() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    String whereClause =
        "o.status = 1 AND date(o.created_at) BETWEEN date(?) AND date(?)";
    List<dynamic> whereArgs = [start, end];

    if (_filter.orderType != null) {
      whereClause += " AND o.order_type = ?";
      whereArgs.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      whereClause += " AND o.location_id = ?";
      whereArgs.add(_filter.locationId);
    }
    if (_filter.waiterId != null) {
      whereClause += " AND o.waiter_id = ?";
      whereArgs.add(_filter.waiterId);
    }

    return await db.rawQuery('''
      SELECT 
        p.name as name, 
        SUM(oi.qty) as total_qty, 
        SUM(oi.qty * oi.price) as total_revenue
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id, p.name
      ORDER BY total_revenue DESC
    ''', whereArgs);
  }

  // Waiter Commissions & Stats
  Future<List<Map<String, dynamic>>> getWaiterStats() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    String whereClause =
        "o.status = 1 AND date(o.created_at) BETWEEN date(?) AND date(?)";
    List<dynamic> whereArgs = [start, end];

    if (_filter.orderType != null) {
      whereClause += " AND o.order_type = ?";
      whereArgs.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      whereClause += " AND o.location_id = ?";
      whereArgs.add(_filter.locationId);
    }

    return await db.rawQuery('''
      SELECT 
        w.name as name, 
        w.type as waiter_type, 
        w.value as waiter_value,
        COUNT(o.id) as order_count,
        SUM(COALESCE(o.total, 0)) as total_sales
      FROM waiters w
      LEFT JOIN orders o ON w.id = o.waiter_id AND $whereClause
      GROUP BY w.id, w.name, w.type, w.value
      HAVING order_count > 0
    ''', whereArgs);
  }

  // Location (Floor) Performance
  Future<List<Map<String, dynamic>>> getLocationStats() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    String whereClause =
        "o.status = 1 AND date(o.created_at) BETWEEN date(?) AND date(?)";
    List<dynamic> whereArgs = [start, end];

    return await db.rawQuery('''
      SELECT 
        l.name, 
        COUNT(o.id) as order_count,
        SUM(o.total) as total_revenue
      FROM locations l
      JOIN orders o ON l.id = o.location_id
      WHERE $whereClause
      GROUP BY l.id
      ORDER BY total_revenue DESC
    ''', whereArgs);
  }

  // Table Performance
  Future<List<Map<String, dynamic>>> getTableStats() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    String whereClause =
        "o.status = 1 AND date(o.created_at) BETWEEN date(?) AND date(?)";
    List<dynamic> whereArgs = [start, end];

    return await db.rawQuery('''
      SELECT 
        t.name as table_name,
        l.name as location_name,
        COUNT(o.id) as order_count,
        SUM(o.total) as total_revenue
      FROM tables t
      JOIN locations l ON t.location_id = l.id
      JOIN orders o ON t.id = o.table_id
      WHERE $whereClause
      GROUP BY t.id
      ORDER BY total_revenue DESC
    ''', whereArgs);
  }

  // Z-Report (Daily Summary)
  Future<Map<String, dynamic>> getZReportData() async {
    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String().split('T')[0];
    final end = _filter.endDate.toIso8601String().split('T')[0];

    // Summary of all PAID orders in range
    final summary = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as count,
        SUM(total) as total,
        SUM(CASE WHEN payment_type = 'Cash' OR payment_type = 'Naqd' THEN total ELSE 0 END) as cash_total,
        SUM(CASE WHEN payment_type = 'Card' OR payment_type = 'Karta' THEN total ELSE 0 END) as card_total,
        SUM(CASE WHEN payment_type = 'Terminal' THEN total ELSE 0 END) as terminal_total,
        MIN(created_at) as first_order,
        MAX(created_at) as last_order
      FROM orders
      WHERE status = 1 
        AND date(created_at) BETWEEN date(?) AND date(?)
    ''',
      [start, end],
    );

    // Waiter sales (using LEFT JOIN so we don't lose orders without waiters)
    final waiterSales = await db.rawQuery(
      '''
      SELECT COALESCE(w.name, 'Admin/Saboy') as name, SUM(o.total) as sales
      FROM orders o
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE o.status = 1 
        AND date(o.created_at) BETWEEN date(?) AND date(?)
      GROUP BY o.waiter_id
    ''',
      [start, end],
    );

    // Category breakdown (Fulfils "order_items properly JOINed" requirement)
    final categorySales = await db.rawQuery(
      '''
      SELECT p.category, SUM(oi.qty) as qty, SUM(oi.qty * oi.price) as total
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE o.status = 1 
        AND date(o.created_at) BETWEEN date(?) AND date(?)
      GROUP BY p.category
      ORDER BY total DESC
    ''',
      [start, end],
    );

    return {
      'date': start == end ? start : "$start - $end",
      'summary': summary.first,
      'waiters': waiterSales,
      'categories': categorySales,
    };
  }

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery(
      '''
      SELECT o.*, l.name as location_name, t.name as table_name, w.name as waiter_name
      FROM orders o
      LEFT JOIN locations l ON o.location_id = l.id
      LEFT JOIN tables t ON o.table_id = t.id
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE o.id = ?
    ''',
      [orderId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery(
      '''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''',
      [orderId],
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/database_helper.dart';
import 'connectivity_provider.dart';

class ReportFilter {
  DateTime startDate;
  DateTime endDate;
  int? orderType;
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
  final ReportFilter _filter = ReportFilter(
    startDate: DateTime.now(),
    endDate: DateTime.now(),
  );

  ReportFilter get filter => _filter;
  DateTime get dateFrom => _filter.startDate;
  DateTime get dateTo => _filter.endDate;

  final bool _isLoading = false;
  bool get isLoading => _isLoading;

  ConnectivityProvider? _connectivity;
  void setConnectivity(ConnectivityProvider c) {
    _connectivity = c;
  }

  bool get _isClient =>
      _connectivity?.mode == ConnectivityMode.client;

  String get _baseUrl => _connectivity?.clientBaseUrl ?? '';

  Map<String, String> get _baseParams => {
        'start': _filter.startDate.toIso8601String(),
        'end': _filter.endDate.toIso8601String(),
        if (_filter.orderType != null) 'order_type': '${_filter.orderType}',
        if (_filter.locationId != null) 'location_id': '${_filter.locationId}',
        if (_filter.waiterId != null) 'waiter_id': '${_filter.waiterId}',
      };

  Future<dynamic> _remoteGet(String path, [Map<String, String>? params]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: params ?? _baseParams,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Report fetch failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>>? _dashboardStatsFuture;

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
    if (endDate != null) {
      // endDate har doim kun oxiri (23:59:59) bo'lishi kerak
      _filter.endDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
    }

    if (clearOrderType) {
      _filter.orderType = null;
    } else if (orderType != null) {
      _filter.orderType = orderType;
    }

    if (clearLocation) {
      _filter.locationId = null;
    } else if (locationId != null) {
      _filter.locationId = locationId;
    }

    if (clearWaiter) {
      _filter.waiterId = null;
    } else if (waiterId != null) {
      _filter.waiterId = waiterId;
    }

    _dashboardStatsFuture = null;
    notifyListeners();
  }

  // ── SQL yordamchi ──────────────────────────────────────────────────────────

  /// Vaqtni hisobga olgan holda to'liq datetime taqqoslash
  /// created_at >= startDate AND created_at <= endDate
  String _whereTime(List<dynamic> args) {
    args
      ..add(_filter.startDate.toIso8601String())
      ..add(_filter.endDate.toIso8601String());
    return "o.created_at >= ? AND o.created_at <= ?";
  }

  String _whereTimePaid(List<dynamic> args) {
    args
      ..add(_filter.startDate.toIso8601String())
      ..add(_filter.endDate.toIso8601String());
    return "o.status = 1 AND o.created_at >= ? AND o.created_at <= ?";
  }

  // ── Dashboard Aggregates ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() {
    return _dashboardStatsFuture ??= _fetchDashboardStats();
  }

  Future<Map<String, dynamic>> _fetchDashboardStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/stats');
      return Map<String, dynamic>.from(data as Map);
    }
    final db = await DatabaseHelper.instance.database;

    final args1 = <dynamic>[];
    final whereTime = _whereTimePaid(args1);

    if (_filter.orderType != null) {
      args1.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      args1.add(_filter.locationId);
    }

    String extra = '';
    if (_filter.orderType != null) extra += ' AND o.order_type = ?';
    if (_filter.locationId != null) extra += ' AND o.location_id = ?';
    if (_filter.waiterId != null) {
      extra += ' AND o.waiter_id = ?';
      args1.add(_filter.waiterId);
    }

    final whereClause = '$whereTime$extra';

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
    ''', args1);

    final args2 = List<dynamic>.from(args1);
    final topQty = await db.rawQuery('''
      SELECT p.name, SUM(oi.qty) as qty
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id
      ORDER BY qty DESC
      LIMIT 5
    ''', args2);

    final args3 = List<dynamic>.from(args1);
    final topRevenue = await db.rawQuery('''
      SELECT p.name, SUM(oi.qty * oi.price) as revenue
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereClause
      GROUP BY p.id
      ORDER BY revenue DESC
      LIMIT 5
    ''', args3);

    return {
      'metrics': orders.first,
      'topQty': topQty,
      'topRevenue': topRevenue,
    };
  }

  // ── Orders List ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/orders');
      return List<Map<String, dynamic>>.from(data as List);
    }
    final db = await DatabaseHelper.instance.database;
    final args = <dynamic>[];
    var where = _whereTime(args);

    if (_filter.orderType != null) {
      where += ' AND o.order_type = ?';
      args.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      where += ' AND o.location_id = ?';
      args.add(_filter.locationId);
    }
    if (_filter.waiterId != null) {
      where += ' AND o.waiter_id = ?';
      args.add(_filter.waiterId);
    }

    return await db.rawQuery('''
      SELECT o.*, l.name as location_name, t.name as table_name, w.name as waiter_name
      FROM orders o
      LEFT JOIN locations l ON o.location_id = l.id
      LEFT JOIN tables t ON o.table_id = t.id
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE $where
      ORDER BY o.created_at DESC
    ''', args);
  }

  // ── Product Stats ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProductStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/products');
      return List<Map<String, dynamic>>.from(data as List);
    }
    final db = await DatabaseHelper.instance.database;
    final args = <dynamic>[];
    var where = _whereTimePaid(args);

    if (_filter.orderType != null) {
      where += ' AND o.order_type = ?';
      args.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      where += ' AND o.location_id = ?';
      args.add(_filter.locationId);
    }
    if (_filter.waiterId != null) {
      where += ' AND o.waiter_id = ?';
      args.add(_filter.waiterId);
    }

    return await db.rawQuery('''
      SELECT
        p.name as name,
        p.category as category,
        SUM(oi.qty) as total_qty,
        SUM(oi.qty * oi.price) as total_revenue,
        p.quantity as current_stock
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE $where
      GROUP BY p.id, p.name, p.quantity
      ORDER BY total_revenue DESC
    ''', args);
  }

  // ── Waiter Stats ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWaiterStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/waiters');
      return List<Map<String, dynamic>>.from(data as List);
    }
    final db = await DatabaseHelper.instance.database;
    final args = <dynamic>[];
    var where = _whereTimePaid(args);

    if (_filter.orderType != null) {
      where += ' AND o.order_type = ?';
      args.add(_filter.orderType);
    }
    if (_filter.locationId != null) {
      where += ' AND o.location_id = ?';
      args.add(_filter.locationId);
    }

    return await db.rawQuery('''
      SELECT
        w.name as name,
        w.type as waiter_type,
        w.value as waiter_value,
        COUNT(o.id) as order_count,
        SUM(COALESCE(o.total, 0)) as total_sales
      FROM waiters w
      LEFT JOIN orders o ON w.id = o.waiter_id AND $where
      GROUP BY w.id, w.name, w.type, w.value
      HAVING order_count > 0
    ''', args);
  }

  // ── Location Stats ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocationStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/locations',
          {'start': _filter.startDate.toIso8601String(), 'end': _filter.endDate.toIso8601String()});
      return List<Map<String, dynamic>>.from(data as List);
    }
    final db = await DatabaseHelper.instance.database;
    final args = <dynamic>[];
    final where = _whereTimePaid(args);

    return await db.rawQuery('''
      SELECT
        l.name,
        COUNT(o.id) as order_count,
        SUM(o.total) as total_revenue
      FROM locations l
      JOIN orders o ON l.id = o.location_id
      WHERE $where
      GROUP BY l.id
      ORDER BY total_revenue DESC
    ''', args);
  }

  // ── Table Stats ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTableStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/tables',
          {'start': _filter.startDate.toIso8601String(), 'end': _filter.endDate.toIso8601String()});
      return List<Map<String, dynamic>>.from(data as List);
    }
    final db = await DatabaseHelper.instance.database;
    final args = <dynamic>[];
    final where = _whereTimePaid(args);

    return await db.rawQuery('''
      SELECT
        t.name as table_name,
        l.name as location_name,
        COUNT(o.id) as order_count,
        SUM(o.total) as total_revenue
      FROM tables t
      JOIN locations l ON t.location_id = l.id
      JOIN orders o ON t.id = o.table_id
      WHERE $where
      GROUP BY t.id
      ORDER BY total_revenue DESC
    ''', args);
  }

  // ── Z-Report ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getZReportData() async {
    final dateLabel = _filter.startDate.toIso8601String().split('T')[0];
    final endLabel = _filter.endDate.toIso8601String().split('T')[0];

    if (_isClient) {
      final data = await _remoteGet('/reports/zreport',
          {'start': _filter.startDate.toIso8601String(), 'end': _filter.endDate.toIso8601String()});
      final m = Map<String, dynamic>.from(data as Map);
      return {
        'date': dateLabel == endLabel ? dateLabel : '$dateLabel - $endLabel',
        'summary': m['summary'],
        'waiters': m['waiterSales'],
        'categories': m['categorySales'],
      };
    }

    final db = await DatabaseHelper.instance.database;
    final start = _filter.startDate.toIso8601String();
    final end = _filter.endDate.toIso8601String();

    final summary = await db.rawQuery('''
      SELECT
        COUNT(*) as count,
        SUM(total) as total,
        SUM(CASE WHEN payment_type = 'Cash' OR payment_type = 'Naqd' THEN total ELSE 0 END) as cash_total,
        SUM(CASE WHEN payment_type = 'Card' OR payment_type = 'Karta' THEN total ELSE 0 END) as card_total,
        SUM(CASE WHEN payment_type = 'Terminal' THEN total ELSE 0 END) as terminal_total,
        MIN(created_at) as first_order,
        MAX(created_at) as last_order
      FROM orders
      WHERE status = 1 AND created_at >= ? AND created_at <= ?
    ''', [start, end]);

    final waiterSales = await db.rawQuery('''
      SELECT COALESCE(w.name, 'Admin/Saboy') as name, SUM(o.total) as sales
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
      'date': dateLabel == endLabel ? dateLabel : '$dateLabel - $endLabel',
      'summary': summary.first,
      'waiters': waiterSales,
      'categories': categorySales,
    };
  }

  // ── Order Details ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    final db = await DatabaseHelper.instance.database;
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
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);
  }
}

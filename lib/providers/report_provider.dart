import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
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

  bool _useCloud = false;
  bool get useCloud => false; // Hardcoded to false to prevent fetching data from Supabase for now

  void setUseCloud(bool val) {
    // _useCloud = val; // Disabled to prevent any Supabase sync/retrieval
    _dashboardStatsFuture = null;
    notifyListeners();
  }

  ConnectivityProvider? _connectivity;
  void setConnectivity(ConnectivityProvider c) {
    _connectivity = c;
  }

  bool get _isClient =>
      _connectivity?.mode == ConnectivityMode.client;

  List<Map<String, dynamic>> _applyFilters(List<dynamic> rawOrders) {
    var filtered = List<Map<String, dynamic>>.from(rawOrders);
    if (_filter.orderType != null) {
      filtered = filtered.where((o) => o['order_type'] == _filter.orderType).toList();
    }
    if (_filter.locationId != null) {
      filtered = filtered.where((o) => o['location_id'] == _filter.locationId).toList();
    }
    if (_filter.waiterId != null) {
      filtered = filtered.where((o) => o['waiter_id'] == _filter.waiterId).toList();
    }
    return filtered;
  }

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
    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('*')
            .eq('status', 1)
            .gte('created_at', start)
            .lte('created_at', end);
            
        final orders = _applyFilters(ordersRaw);
        
        if (orders.isEmpty) {
          return {
            'metrics': {
              'count': 0,
              'total': 0.0,
              'avg_check': 0.0,
              'cash_total': 0.0,
              'card_total': 0.0,
              'terminal_total': 0.0,
              'dine_in_total': 0.0,
              'takeaway_total': 0.0
            },
            'topQty': [],
            'topRevenue': [],
          };
        }
        
        // Calculate metrics
        int count = orders.length;
        double total = orders.fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double avgCheck = count > 0 ? total / count : 0.0;
        
        double cashTotal = orders.where((o) => o['payment_type'] == 'Cash' || o['payment_type'] == 'Naqd').fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double cardTotal = orders.where((o) => o['payment_type'] == 'Card' || o['payment_type'] == 'Karta').fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double terminalTotal = orders.where((o) => o['payment_type'] == 'Terminal').fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        
        double dineInTotal = orders.where((o) => o['order_type'] == 0).fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double takeawayTotal = orders.where((o) => o['order_type'] == 1).fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        
        final orderIds = orders.map((o) => o['id']).toList();
        final itemsRaw = await Supabase.instance.client
            .from('order_items')
            .select('product_name, qty, price')
            .inFilter('order_id', orderIds);
            
        final Map<String, double> qtyMap = {};
        final Map<String, double> revMap = {};
        for (final item in itemsRaw) {
          final name = item['product_name'] ?? 'Nomuvofiq Mahsulot';
          final qty = ((item['qty'] ?? 0.0) as num).toDouble();
          final price = ((item['price'] ?? 0.0) as num).toDouble();
          qtyMap[name] = (qtyMap[name] ?? 0.0) + qty;
          revMap[name] = (revMap[name] ?? 0.0) + (qty * price);
        }
        
        final topQty = qtyMap.entries
            .map((e) => {'name': e.key, 'qty': e.value})
            .toList()
          ..sort((a, b) => (b['qty'] as double).compareTo(a['qty'] as double));
          
        final topRevenue = revMap.entries
            .map((e) => {'name': e.key, 'revenue': e.value})
            .toList()
          ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
          
        return {
          'metrics': {
            'count': count,
            'total': total,
            'avg_check': avgCheck,
            'cash_total': cashTotal,
            'card_total': cardTotal,
            'terminal_total': terminalTotal,
            'dine_in_total': dineInTotal,
            'takeaway_total': takeawayTotal
          },
          'topQty': topQty.take(5).toList(),
          'topRevenue': topRevenue.take(5).toList(),
        };
      } catch (e) {
        debugPrint('Cloud Dashboard Stats error, falling back to local: $e');
      }
    }

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
    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('*')
            .gte('created_at', start)
            .lte('created_at', end)
            .order('created_at', ascending: false);
            
        final filtered = _applyFilters(ordersRaw);
        if (filtered.isEmpty) return [];

        // Fetch lookups in parallel
        final results = await Future.wait([
          Supabase.instance.client.from('waiters').select('id, name'),
          Supabase.instance.client.from('locations').select('id, name'),
          Supabase.instance.client.from('tables').select('id, name'),
        ]);

        final waiterMap = {for (var w in results[0]) w['id']: w['name']};
        final locationMap = {for (var l in results[1]) l['id']: l['name']};
        final tableMap = {for (var t in results[2]) t['id']: t['name']};

        return filtered.map((row) {
          final map = Map<String, dynamic>.from(row);
          map['waiter_name'] = waiterMap[row['waiter_id']];
          map['location_name'] = locationMap[row['location_id']];
          map['table_name'] = tableMap[row['table_id']];
          return map;
        }).toList();
      } catch (e) {
        debugPrint('Cloud getOrders error, falling back: $e');
      }
    }

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
    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('id, order_type, location_id, waiter_id')
            .eq('status', 1)
            .gte('created_at', start)
            .lte('created_at', end);
            
        final orders = _applyFilters(ordersRaw);
        if (orders.isEmpty) return [];
        
        final orderIds = orders.map((o) => o['id']).toList();
        final itemsRaw = await Supabase.instance.client
            .from('order_items')
            .select('product_name, qty, price, product_id')
            .inFilter('order_id', orderIds);
            
        final Map<String, Map<String, dynamic>> productStats = {};
        for (final item in itemsRaw) {
          final name = item['product_name'] ?? 'Nomuvofiq Mahsulot';
          final qty = ((item['qty'] ?? 0.0) as num).toDouble();
          final price = ((item['price'] ?? 0.0) as num).toDouble();
          
          if (!productStats.containsKey(name)) {
            productStats[name] = {
              'name': name,
              'category': 'Bulut',
              'total_qty': 0.0,
              'total_revenue': 0.0,
              'current_stock': null
            };
          }
          
          productStats[name]!['total_qty'] = (productStats[name]!['total_qty'] as double) + qty;
          productStats[name]!['total_revenue'] = (productStats[name]!['total_revenue'] as double) + (qty * price);
        }
        
        final result = productStats.values.toList();
        result.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
        return result;
      } catch (e) {
        debugPrint('Cloud getProductStats error, falling back: $e');
      }
    }

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
    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('*')
            .eq('status', 1)
            .gte('created_at', start)
            .lte('created_at', end);
            
        final orders = _applyFilters(ordersRaw);
        if (orders.isEmpty) return [];

        final waiters = await Supabase.instance.client.from('waiters').select('id, name, type, value');
        final waiterMap = {for (var w in waiters) w['id']: w};
        
        final Map<String, Map<String, dynamic>> waiterStats = {};
        for (final o in orders) {
          final waiter = waiterMap[o['waiter_id']];
          final waiterName = waiter?['name'] ?? 'Kassa';
          final waiterType = waiter?['type'] ?? 0;
          final waiterValue = ((waiter?['value'] ?? 0.0) as num).toDouble();
          final totalSales = ((o['total'] ?? 0.0) as num).toDouble();
          
          if (!waiterStats.containsKey(waiterName)) {
            waiterStats[waiterName] = {
              'name': waiterName,
              'waiter_type': waiterType,
              'waiter_value': waiterValue,
              'order_count': 0,
              'total_sales': 0.0
            };
          }
          
          waiterStats[waiterName]!['order_count'] = (waiterStats[waiterName]!['order_count'] as int) + 1;
          waiterStats[waiterName]!['total_sales'] = (waiterStats[waiterName]!['total_sales'] as double) + totalSales;
        }
        
        return waiterStats.values.toList();
      } catch (e) {
        debugPrint('Cloud getWaiterStats error, falling back: $e');
      }
    }

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
    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('*')
            .eq('status', 1)
            .gte('created_at', start)
            .lte('created_at', end);
            
        final orders = _applyFilters(ordersRaw);
        if (orders.isEmpty) return [];

        final locations = await Supabase.instance.client.from('locations').select('id, name');
        final locationMap = {for (var l in locations) l['id']: l['name']};
        
        final Map<String, Map<String, dynamic>> locationStats = {};
        for (final o in orders) {
          final locName = locationMap[o['location_id']] ?? 'Noma\'lum Joy';
          final totalSales = ((o['total'] ?? 0.0) as num).toDouble();
          
          if (!locationStats.containsKey(locName)) {
            locationStats[locName] = {
              'name': locName,
              'order_count': 0,
              'total_revenue': 0.0
            };
          }
          
          locationStats[locName]!['order_count'] = (locationStats[locName]!['order_count'] as int) + 1;
          locationStats[locName]!['total_revenue'] = (locationStats[locName]!['total_revenue'] as double) + totalSales;
        }
        
        final result = locationStats.values.toList();
        result.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
        return result;
      } catch (e) {
        debugPrint('Cloud getLocationStats error, falling back: $e');
      }
    }

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
    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('*')
            .eq('status', 1)
            .gte('created_at', start)
            .lte('created_at', end);
            
        final orders = _applyFilters(ordersRaw);
        if (orders.isEmpty) return [];

        final results = await Future.wait([
          Supabase.instance.client.from('tables').select('id, name, location_id'),
          Supabase.instance.client.from('locations').select('id, name'),
        ]);

        final locationMap = {for (var l in results[1]) l['id']: l['name']};
        final tableMap = {for (var t in results[0]) t['id']: t};
        
        final Map<String, Map<String, dynamic>> tableStats = {};
        for (final o in orders) {
          final t = tableMap[o['table_id']];
          final tableName = t?['name'] ?? 'Noma\'lum Stol';
          final locName = locationMap[t?['location_id']] ?? '';
          final totalSales = ((o['total'] ?? 0.0) as num).toDouble();
          
          final key = '$tableName-$locName';
          if (!tableStats.containsKey(key)) {
            tableStats[key] = {
              'table_name': tableName,
              'location_name': locName,
              'order_count': 0,
              'total_revenue': 0.0
            };
          }
          
          tableStats[key]!['order_count'] = (tableStats[key]!['order_count'] as int) + 1;
          tableStats[key]!['total_revenue'] = (tableStats[key]!['total_revenue'] as double) + totalSales;
        }
        
        final result = tableStats.values.toList();
        result.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
        return result;
      } catch (e) {
        debugPrint('Cloud getTableStats error, falling back: $e');
      }
    }

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

    if (_useCloud) {
      try {
        final start = _filter.startDate.toIso8601String();
        final end = _filter.endDate.toIso8601String();
        
        final ordersRaw = await Supabase.instance.client
            .from('orders')
            .select('*')
            .eq('status', 1)
            .gte('created_at', start)
            .lte('created_at', end);
            
        final orders = _applyFilters(ordersRaw);
        
        if (orders.isEmpty) {
          return {
            'date': dateLabel == endLabel ? dateLabel : '$dateLabel - $endLabel',
            'summary': {
              'count': 0,
              'total': 0.0,
              'cash_total': 0.0,
              'card_total': 0.0,
              'terminal_total': 0.0,
              'first_order': null,
              'last_order': null
            },
            'waiters': [],
            'categories': [],
          };
        }
        
        // Calculate summary
        int count = orders.length;
        double total = orders.fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double cashTotal = orders.where((o) => o['payment_type'] == 'Cash' || o['payment_type'] == 'Naqd').fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double cardTotal = orders.where((o) => o['payment_type'] == 'Card' || o['payment_type'] == 'Karta').fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        double terminalTotal = orders.where((o) => o['payment_type'] == 'Terminal').fold(0.0, (sum, o) => sum + ((o['total'] ?? 0.0) as num).toDouble());
        
        final sortedDates = orders.map((o) => o['created_at'] as String).toList()..sort();
        final firstOrder = sortedDates.first;
        final lastOrder = sortedDates.last;
        
        // Fetch lookups in parallel
        final results = await Future.wait([
          Supabase.instance.client.from('waiters').select('id, name'),
          Supabase.instance.client.from('products').select('id, category'),
        ]);

        final waiterMapLookup = {for (var w in results[0]) w['id']: w['name']};
        final productMapLookup = {for (var p in results[1]) p['id']: p['category']};

        // Waiters
        final Map<String, double> waiterMap = {};
        for (final o in orders) {
          final waiterName = waiterMapLookup[o['waiter_id']] ?? 'Admin/Saboy';
          final orderTotal = ((o['total'] ?? 0.0) as num).toDouble();
          waiterMap[waiterName] = (waiterMap[waiterName] ?? 0.0) + orderTotal;
        }
        final waiterSales = waiterMap.entries.map((e) => {'name': e.key, 'sales': e.value}).toList();
        
        // Categories
        final orderIds = orders.map((o) => o['id']).toList();
        final itemsRaw = await Supabase.instance.client
            .from('order_items')
            .select('qty, price, product_id')
            .inFilter('order_id', orderIds);
            
        final Map<String, Map<String, dynamic>> categoryMap = {};
        for (final item in itemsRaw) {
          final categoryName = productMapLookup[item['product_id']] ?? 'Bulut';
          final qty = ((item['qty'] ?? 0.0) as num).toDouble();
          final price = ((item['price'] ?? 0.0) as num).toDouble();
          
          if (!categoryMap.containsKey(categoryName)) {
            categoryMap[categoryName] = {
              'category': categoryName,
              'qty': 0.0,
              'total': 0.0
            };
          }
          categoryMap[categoryName]!['qty'] = (categoryMap[categoryName]!['qty'] as double) + qty;
          categoryMap[categoryName]!['total'] = (categoryMap[categoryName]!['total'] as double) + (qty * price);
        }
        
        final categorySales = categoryMap.values.toList();
        categorySales.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
        
        return {
          'date': dateLabel == endLabel ? dateLabel : '$dateLabel - $endLabel',
          'summary': {
            'count': count,
            'total': total,
            'cash_total': cashTotal,
            'card_total': cardTotal,
            'terminal_total': terminalTotal,
            'first_order': firstOrder,
            'last_order': lastOrder
          },
          'waiters': waiterSales,
          'categories': categorySales,
        };
      } catch (e) {
        debugPrint('Cloud getZReportData error, falling back: $e');
      }
    }

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

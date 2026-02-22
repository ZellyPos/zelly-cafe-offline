import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/table.dart';
import 'connectivity_provider.dart';

class TableProvider extends ChangeNotifier {
  List<TableModel> _tables = [];
  bool _isLoading = false;

  List<TableModel> get tables => _tables;
  bool get isLoading => _isLoading;

  Future<void> loadTables({
    ConnectivityProvider? connectivity,
    bool silent = false,
    bool forceRemote = false,
  }) async {
    // Only show loading indicator on initial load
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      List<Map<String, dynamic>> data;

      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData('/tables/summary');
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        final db = await DatabaseHelper.instance.database;
        data = await db.rawQuery('''
      SELECT t.*, 
             o.id as order_id, 
             o.waiter_id, 
             o.opened_at, 
             o.total as order_total, 
             w.name as waiter_name
      FROM tables t
      LEFT JOIN orders o ON t.active_order_id = o.id AND o.status = 0
      LEFT JOIN waiters w ON o.waiter_id = w.id
    ''');
      }

      _tables = data.map((item) {
        ActiveOrderInfo? activeOrder;
        if (item['order_id'] != null) {
          activeOrder = ActiveOrderInfo(
            orderId: item['order_id'] as String,
            waiterId: item['waiter_id'] as int?,
            waiterName: item['waiter_name'] as String?,
            totalAmount: (item['order_total'] as num).toDouble(),
            openedAt: item['opened_at'] != null
                ? DateTime.parse(item['opened_at'] as String)
                : null,
          );
        }
        return TableModel.fromMap(item, activeOrder: activeOrder);
      }).toList();
    } catch (e) {
      debugPrint("Error loading tables: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTable(
    TableModel table, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', table.toMap());
    } else {
      await DatabaseHelper.instance.insert('tables', table.toMap());
    }
    await loadTables(connectivity: connectivity);
  }

  Future<void> updateTable(
    TableModel table, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', table.toMap());
    } else {
      await DatabaseHelper.instance.update('tables', table.toMap(), 'id = ?', [
        table.id,
      ]);
    }
    await loadTables(connectivity: connectivity);
  }

  Future<bool> deleteTable(int id, {ConnectivityProvider? connectivity}) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      // In client mode, we trust the server to handle validation if needed,
      // but for better UX we could check local state if it's mirrored correctly.
      final success = await connectivity.deleteRemoteData('/tables/$id');
      if (success) {
        await loadTables(connectivity: connectivity);
      }
      return success;
    } else {
      // Check if table has an OPEN order
      final openOrders = await DatabaseHelper.instance.database.then(
        (db) => db.query(
          'orders',
          where: 'table_id = ? AND status = 0',
          whereArgs: [id],
        ),
      );

      if (openOrders.isNotEmpty) {
        return false; // Cannot delete
      }

      await DatabaseHelper.instance.delete('tables', 'id = ?', [id]);
      await loadTables();
      return true;
    }
  }

  Future<void> updateTableStatus(
    int id,
    int status, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', {
        'id': id,
        'status': status,
      });
    } else {
      await DatabaseHelper.instance.update(
        'tables',
        {'status': status},
        'id = ?',
        [id],
      );
    }
    await loadTables(connectivity: connectivity);
  }

  Future<void> updateTableLayout(
    int id,
    double x,
    double y,
    double width,
    double height, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
    } else {
      await DatabaseHelper.instance.update(
        'tables',
        {'x': x, 'y': y, 'width': width, 'height': height},
        'id = ?',
        [id],
      );
    }

    // Locally update the table in the list to avoid full reload
    final index = _tables.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        x: x,
        y: y,
        width: width,
        height: height,
      );
      notifyListeners();
    }
  }

  Future<List<TableModel>> getTablesForLocation(int? locationId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      String query = '''
        SELECT t.*, 
               o.id as order_id, 
               o.waiter_id, 
               o.opened_at, 
               o.total as order_total, 
               w.name as waiter_name
        FROM tables t
        LEFT JOIN orders o ON t.active_order_id = o.id AND o.status = 0
        LEFT JOIN waiters w ON o.waiter_id = w.id
      ''';

      List<dynamic> whereArgs = [];
      if (locationId != null) {
        query += ' WHERE t.location_id = ?';
        whereArgs.add(locationId);
      }

      final data = await db.rawQuery(query, whereArgs);

      return data.map((item) {
        ActiveOrderInfo? activeOrder;
        if (item['order_id'] != null) {
          activeOrder = ActiveOrderInfo(
            orderId: item['order_id'] as String,
            waiterId: item['waiter_id'] as int?,
            waiterName: item['waiter_name'] as String?,
            totalAmount: (item['order_total'] as num).toDouble(),
            openedAt: item['opened_at'] != null
                ? DateTime.parse(item['opened_at'] as String)
                : null,
          );
        }
        return TableModel.fromMap(item, activeOrder: activeOrder);
      }).toList();
    } catch (e) {
      debugPrint("Error getting tables for location: $e");
      return [];
    }
  }
}

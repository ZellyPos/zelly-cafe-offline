import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _isSyncing = false;
  Timer? _syncTimer;

  // Start periodic sync (e.g., every 30 seconds)
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncNow();
    });
  }

  // Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Main sync function
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final hasInternet = await _checkInternet();
      if (!hasInternet) {
        _isSyncing = false;
        return;
      }

      final db = await DatabaseHelper.instance.database;

      // 1. Sync catalogs (tiny tables, upsert all to maintain cloud lookup consistency)
      await _syncCatalogs(db);

      // 2. Sync shifts (dependency for orders and cash movements)
      await _syncShifts(db);

      // 3. Sync orders & order_items
      await _syncOrders(db);

      // 4. Sync expenses
      await _syncExpenses(db);

      // 5. Sync transactions
      await _syncTransactions(db);

      // 6. Sync cash movements
      await _syncCashMovements(db);

    } catch (e, stack) {
      debugPrint('Sync Service Error: $e');
      debugPrint(stack.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static const Map<String, List<String>> _allowedFields = {
    'categories': ['id', 'name', 'color', 'sort_order'],
    'products': [
      'id',
      'name',
      'price',
      'category',
      'is_active',
      'image_path',
      'is_set',
      'track_type',
      'allow_negative_stock',
      'sort_order',
      'quantity',
      'unit',
      'no_service_charge'
    ],
    'product_bundles': ['id', 'bundle_id', 'product_id', 'qty', 'price'],
    'waiters': ['id', 'name', 'type', 'value', 'is_active'],
    'users': ['id', 'name', 'pin', 'role', 'is_active'],
    'expense_categories': ['id', 'name'],
    'customers': ['id', 'name', 'phone', 'balance', 'is_active'],
    'couriers': ['id', 'name', 'phone', 'is_active'],
    'delivery_zones': ['id', 'name', 'fee', 'is_active'],
    'shifts': [
      'id',
      'opened_at',
      'closed_at',
      'opened_by',
      'closed_by',
      'status',
      'start_cash',
      'end_cash'
    ],
    'orders': [
      'id',
      'total',
      'payment_type',
      'created_at',
      'order_type',
      'table_id',
      'location_id',
      'waiter_id',
      'status',
      'opened_at',
      'closed_at',
      'room_charge',
      'paid_amount',
      'receipt_change',
      'food_total',
      'room_total',
      'service_total',
      'grand_total',
      'shift_id',
      'daily_number',
      'note'
    ],
    'order_items': ['id', 'order_id', 'product_id', 'product_name', 'qty', 'price'],
    'expenses': ['id', 'amount', 'category_id', 'note', 'created_at', 'shift_id'],
    'transactions': ['id', 'customer_id', 'amount', 'type', 'note', 'created_at', 'order_id'],
    'cash_movements': ['id', 'shift_id', 'amount', 'type', 'note', 'created_at'],
  };

  Map<String, dynamic> _sanitizeRow(String tableName, Map<String, dynamic> row) {
    final allowed = _allowedFields[tableName];
    if (allowed == null) return Map<String, dynamic>.from(row);
    
    final sanitized = <String, dynamic>{};
    for (final key in allowed) {
      if (row.containsKey(key)) {
        sanitized[key] = row[key];
      }
    }
    return sanitized;
  }

  Future<void> _syncCatalogs(var db) async {
    try {
      // Sync categories
      final categories = await db.query('categories');
      if (categories.isNotEmpty) {
        await Supabase.instance.client.from('categories').upsert(
              categories.map((c) => _sanitizeRow('categories', c)).toList(),
            );
      }

      // Sync products
      final products = await db.query('products');
      if (products.isNotEmpty) {
        await Supabase.instance.client.from('products').upsert(
              products.map((p) => _sanitizeRow('products', p)).toList(),
            );
      }

      // Sync product_bundles
      final bundles = await db.query('product_bundles');
      if (bundles.isNotEmpty) {
        await Supabase.instance.client.from('product_bundles').upsert(
              bundles.map((b) => _sanitizeRow('product_bundles', b)).toList(),
            );
      }

      // Sync waiters
      final waiters = await db.query('waiters');
      if (waiters.isNotEmpty) {
        await Supabase.instance.client.from('waiters').upsert(
              waiters.map((w) => _sanitizeRow('waiters', w)).toList(),
            );
      }

      // Sync users
      final users = await db.query('users');
      if (users.isNotEmpty) {
        await Supabase.instance.client.from('users').upsert(
              users.map((u) => _sanitizeRow('users', u)).toList(),
            );
      }

      // Sync expense_categories
      final expenseCats = await db.query('expense_categories');
      if (expenseCats.isNotEmpty) {
        await Supabase.instance.client.from('expense_categories').upsert(
              expenseCats.map((ec) => _sanitizeRow('expense_categories', ec)).toList(),
            );
      }

      // Sync customers
      final customers = await db.query('customers');
      if (customers.isNotEmpty) {
        await Supabase.instance.client.from('customers').upsert(
              customers.map((c) => _sanitizeRow('customers', c)).toList(),
            );
      }

      // Sync couriers
      final couriers = await db.query('couriers');
      if (couriers.isNotEmpty) {
        await Supabase.instance.client.from('couriers').upsert(
              couriers.map((cr) => _sanitizeRow('couriers', cr)).toList(),
            );
      }

      // Sync delivery_zones
      final zones = await db.query('delivery_zones');
      if (zones.isNotEmpty) {
        await Supabase.instance.client.from('delivery_zones').upsert(
              zones.map((z) => _sanitizeRow('delivery_zones', z)).toList(),
            );
      }
    } catch (e) {
      debugPrint('Sync Catalogs Error (non-blocking): $e');
    }
  }

  Future<void> _syncShifts(var db) async {
    final unsynced = await db.query(
      'shifts',
      where: 'is_synced = 0',
    );

    for (final row in unsynced) {
      final data = _sanitizeRow('shifts', row);
      
      try {
        await Supabase.instance.client.from('shifts').upsert(data);
        await db.update(
          'shifts',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Error syncing shift ${row['id']}: $e');
      }
    }
  }

  Future<void> _syncOrders(var db) async {
    final unsynced = await db.query(
      'orders',
      where: 'is_synced = 0',
    );

    for (final row in unsynced) {
      final orderId = row['id'] as String;
      
      // Get order items
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final orderData = _sanitizeRow('orders', row);
      final itemsData = items.map((item) => _sanitizeRow('order_items', item)).toList();

      try {
        // Upsert order first
        await Supabase.instance.client.from('orders').upsert(orderData);

        // Upsert order items if any
        if (itemsData.isNotEmpty) {
          await Supabase.instance.client.from('order_items').upsert(itemsData);
        }

        // Mark as synced locally
        await db.update(
          'orders',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      } catch (e) {
        debugPrint('Error syncing order $orderId: $e');
      }
    }
  }

  Future<void> _syncExpenses(var db) async {
    final unsynced = await db.query(
      'expenses',
      where: 'is_synced = 0',
    );

    for (final row in unsynced) {
      final data = _sanitizeRow('expenses', row);

      try {
        await Supabase.instance.client.from('expenses').upsert(data);
        await db.update(
          'expenses',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Error syncing expense ${row['id']}: $e');
      }
    }
  }

  Future<void> _syncTransactions(var db) async {
    final unsynced = await db.query(
      'transactions',
      where: 'is_synced = 0',
    );

    for (final row in unsynced) {
      final data = _sanitizeRow('transactions', row);

      try {
        await Supabase.instance.client.from('transactions').upsert(data);
        await db.update(
          'transactions',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Error syncing transaction ${row['id']}: $e');
      }
    }
  }

  Future<void> _syncCashMovements(var db) async {
    final unsynced = await db.query(
      'cash_movements',
      where: 'is_synced = 0',
    );

    for (final row in unsynced) {
      final data = _sanitizeRow('cash_movements', row);

      try {
        await Supabase.instance.client.from('cash_movements').upsert(data);
        await db.update(
          'cash_movements',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Error syncing cash movement ${row['id']}: $e');
      }
    }
  }
}



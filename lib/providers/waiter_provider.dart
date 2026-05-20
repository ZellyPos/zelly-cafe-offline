import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/waiter.dart';
import 'connectivity_provider.dart';

class WaiterProvider with ChangeNotifier {
  List<Waiter> _waiters = [];
  bool _isLoading = false;

  List<Waiter> get waiters => _waiters;
  bool get isLoading => _isLoading;

  Future<void> loadWaiters({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData('/waiters');
        data = List<Map<String, dynamic>>.from(remoteData);

        // Sync to local DB
        final db = await DatabaseHelper.instance.database;
        await db.transaction((txn) async {
          await txn.delete('waiters');
          for (var item in data) {
            final waiterForDb = Map<String, dynamic>.from(item);
            // permissions is a list from API, but a string in DB
            if (waiterForDb['permissions'] is List) {
              waiterForDb['permissions'] =
                  (waiterForDb['permissions'] as List).join(',');
            }
            await txn.insert('waiters', waiterForDb);
          }
        });
      } else {
        data = await DatabaseHelper.instance.queryAll('waiters');
      }
      _waiters = data.map((item) => Waiter.fromMap(item)).toList();
    } catch (e) {
      debugPrint("Error loading waiters: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addWaiter(
    Waiter waiter, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
        final ok = await connectivity.postRemoteData('/waiters', waiter.toMap());
        if (!ok) return 'Serverga qo\'shishda xatolik yuz berdi';
      } else {
        final duplicate = await _findPinDuplicate(waiter.pinCode, excludeId: null);
        if (duplicate != null) {
          return 'Bu PIN kod (${waiter.pinCode}) allaqachon "$duplicate" xodimiga biriktirilgan';
        }
        await DatabaseHelper.instance.insert('waiters', waiter.toMap());
      }
      await loadWaiters(connectivity: connectivity);
      return null;
    } catch (e) {
      return 'Xatolik: $e';
    }
  }

  Future<String?> updateWaiter(
    Waiter waiter, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
        final ok = await connectivity.postRemoteData('/waiters', waiter.toMap());
        if (!ok) return 'Serverda yangilashda xatolik yuz berdi';
      } else {
        final duplicate = await _findPinDuplicate(waiter.pinCode, excludeId: waiter.id);
        if (duplicate != null) {
          return 'Bu PIN kod (${waiter.pinCode}) allaqachon "$duplicate" xodimiga biriktirilgan';
        }
        await DatabaseHelper.instance.update(
          'waiters',
          waiter.toMap(),
          'id = ?',
          [waiter.id!],
        );
      }
      await loadWaiters(connectivity: connectivity);
      return null;
    } catch (e) {
      return 'Xatolik: $e';
    }
  }

  Future<String?> bulkUpdateCommission({
    required int type,
    required double value,
    int? onlyCurrentType,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final where = onlyCurrentType != null
          ? "name != 'Kassa' AND type = $onlyCurrentType"
          : "name != 'Kassa'";
      await db.rawUpdate(
        "UPDATE waiters SET type = ?, value = ? WHERE $where",
        [type, value],
      );
      await loadWaiters();
      return null;
    } catch (e) {
      return 'Xatolik: $e';
    }
  }

  Future<String?> bulkUpdatePermissions({
    required List<String> add,    // qo'shiladigan ruxsatlar
    required List<String> remove, // o'chiriladigan ruxsatlar
    int? onlyCurrentType,         // null=hammasi, 0=fixed, 1=percent
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final where = onlyCurrentType != null
          ? "name != 'Kassa' AND type = $onlyCurrentType"
          : "name != 'Kassa'";
      final rows = await db.rawQuery(
        "SELECT id, permissions FROM waiters WHERE $where",
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
          "UPDATE waiters SET permissions = ? WHERE id = ?",
          [perms.join(','), row['id']],
        );
      }
      await batch.commit(noResult: true);
      await loadWaiters();
      return null;
    } catch (e) {
      return 'Xatolik: $e';
    }
  }

  /// PIN duplikatini tekshiradi. Mavjud bo'lsa xodim nomini qaytaradi.
  Future<String?> _findPinDuplicate(String? pin, {required int? excludeId}) async {
    if (pin == null || pin.isEmpty) return null;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'waiters',
      where: excludeId != null ? 'pin_code = ? AND id != ?' : 'pin_code = ?',
      whereArgs: excludeId != null ? [pin, excludeId] : [pin],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['name']?.toString() ?? 'Boshqa xodim';
  }

  Future<bool> deleteWaiter(
    int id, {
    bool isAdmin = false,
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final success = await connectivity.deleteRemoteData('/waiters/$id');
      if (success) {
        await loadWaiters(connectivity: connectivity);
      }
      return success;
    } else {
      if (!isAdmin) {
        return false; // Only admin can delete locally
      }

      // Check if waiter has orders
      final orders = await DatabaseHelper.instance.queryByColumn(
        'orders',
        'waiter_id',
        id,
      );
      if (orders.isNotEmpty) {
        return false; // Cannot delete if orders exist
      }

      await DatabaseHelper.instance.delete('waiters', 'id = ?', [id]);
      await loadWaiters(connectivity: connectivity);
      return true;
    }
  }

  Future<Map<String, dynamic>> getWaiterProfileData(
    int waiterId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    // 1. Get waiter info to know type/value
    final waiterData = await db.query(
      'waiters',
      where: 'id = ?',
      whereArgs: [waiterId],
      limit: 1,
    );
    if (waiterData.isEmpty) return {};
    final type = waiterData.first['type'] as int;
    final value = (waiterData.first['value'] as num).toDouble();
    final isKassa = waiterData.first['name'] == "Kassa";

    // 2. Get orders summary (only status=1)
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

    // 3. Calculate earned
    double earned = 0;
    if (!isKassa) {
      if (type == 1) {
        // Percentage
        earned = totalSales * (value / 100);
      } else {
        // Fixed per order
        earned = orderCount * value;
      }
    }

    // 4. Get total paid in this period
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

    // 5. Calculate payable
    double payable = earned - totalPaid;

    // 6. Get orders list
    final orders = await db.query(
      'orders',
      where: 'waiter_id = ? AND status = 1 AND created_at BETWEEN ? AND ?',
      whereArgs: [waiterId, startStr, endStr],
      orderBy: 'created_at DESC',
      limit: 50,
    );

    // 7. Get payments list
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

  Future<void> addSalaryPayment(int waiterId, int amount, String? note) async {
    await DatabaseHelper.instance.insert('waiter_payments', {
      'waiter_id': waiterId,
      'amount': amount,
      'paid_at': DateTime.now().toIso8601String(),
      'note': note,
      'created_by': 'Admin', // Default for now
    });
  }
}

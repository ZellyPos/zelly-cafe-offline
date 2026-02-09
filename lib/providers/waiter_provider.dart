import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/waiter.dart';

class WaiterProvider with ChangeNotifier {
  List<Waiter> _waiters = [];
  bool _isLoading = false;

  List<Waiter> get waiters => _waiters;
  bool get isLoading => _isLoading;

  Future<void> loadWaiters() async {
    _isLoading = true;
    notifyListeners();

    final data = await DatabaseHelper.instance.queryAll('waiters');
    _waiters = data.map((item) => Waiter.fromMap(item)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addWaiter(Waiter waiter) async {
    await DatabaseHelper.instance.insert('waiters', waiter.toMap());
    await loadWaiters();
  }

  Future<void> updateWaiter(Waiter waiter) async {
    await DatabaseHelper.instance.update('waiters', waiter.toMap(), 'id = ?', [
      waiter.id,
    ]);
    await loadWaiters();
  }

  Future<bool> deleteWaiter(int id, {bool isAdmin = false}) async {
    if (!isAdmin) {
      return false; // Only admin can delete
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
    await loadWaiters();
    return true;
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
      SELECT COUNT(*) as count, SUM(total) as total 
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

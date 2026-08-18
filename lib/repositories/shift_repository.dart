import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database_helper.dart';
import '../models/shift_models.dart';

class ShiftRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Smenalar (Shifts) ---

  /// Hozirgi ochiq smenani olish
  Future<Shift?> getOpenShift() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shifts',
      where: 'status = 0',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Shift.fromMap(maps.first);
  }

  /// Yangi smena ochish
  Future<int> openShift(Shift shift) async {
    final db = await _dbHelper.database;
    return await db.insert('shifts', shift.toMap());
  }

  /// Smenani yopish
  Future<void> updateShift(Shift shift) async {
    final db = await _dbHelper.database;
    await db.update(
      'shifts',
      shift.toMap(),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  // --- Kassa harakatlari (Cash Movements) ---

  /// Kassa harakatini qo'shish
  Future<int> insertCashMovement(
    CashMovement movement, {
    Transaction? txn,
  }) async {
    final db = txn ?? (await _dbHelper.database);
    return await db.insert('cash_movements', movement.toMap());
  }

  /// Ma'lum bir smenadagi barcha kassa harakatlarini olish
  Future<List<CashMovement>> getShiftMovements(int shiftId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_movements',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
    );
    return List.generate(maps.length, (i) => CashMovement.fromMap(maps[i]));
  }

  // --- Tarix ---

  /// Smena tarixini olish (eng yangi birinchi)
  Future<List<Shift>> getShiftHistory({int limit = 60}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'shifts',
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    return maps.map((m) => Shift.fromMap(m)).toList();
  }

  /// Smena buyurtmalar sonini olish
  Future<int> getShiftOrderCount(int shiftId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM orders WHERE shift_id = ? AND status = 1',
      [shiftId],
    );
    return (res.first['cnt'] as int?) ?? 0;
  }

  /// Smena ochgan va yopgan foydalanuvchi ismlarini olish
  Future<Map<String, String?>> getShiftUserNames(
    int openedBy,
    int? closedBy,
  ) async {
    final db = await _dbHelper.database;
    String? openedName;
    String? closedName;

    final openedRes = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [openedBy],
    );
    if (openedRes.isNotEmpty) openedName = openedRes.first['name'] as String?;

    if (closedBy != null) {
      final closedRes = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [closedBy],
      );
      if (closedRes.isNotEmpty) {
        closedName = closedRes.first['name'] as String?;
      }
    }
    return {'opened': openedName, 'closed': closedName};
  }

  // --- Hisobotlar (Agregatsiya) ---

  /// Smena bo'yicha sotuvlar summasini olish
  Future<ShiftSummary> getShiftSalesSummary(int shiftId) async {
    final db = await _dbHelper.database;

    // To'lov turi bo'yicha sotuvlar — order_payments jadvalidan
    final salesData = await db.rawQuery(
      '''
      SELECT op.payment_type, SUM(op.amount) as total_sum
      FROM order_payments op
      JOIN orders o ON op.order_id = o.id
      WHERE o.shift_id = ? AND o.status = 1
      GROUP BY op.payment_type
      ''',
      [shiftId],
    );

    double cash = 0, card = 0, terminal = 0, debt = 0, bonus = 0, transfer = 0;
    for (var row in salesData) {
      final type = row['payment_type'].toString().toLowerCase();
      final sum = (row['total_sum'] as num?)?.toDouble() ?? 0.0;
      if (type == 'cash' || type == 'naqd') {
        cash += sum;
      } else if (type == 'card' || type == 'karta') {
        card += sum;
      } else if (type == 'terminal') {
        terminal += sum;
      } else if (type == 'debt' || type == 'nasiya') {
        debt += sum;
      } else if (type == 'bonus') {
        bonus += sum;
      } else if (type == 'transfer') {
        transfer += sum;
      }
    }

    // Kassa harakatlari
    final movementData = await db.rawQuery(
      '''
      SELECT type, SUM(amount) as total_sum 
      FROM cash_movements 
      WHERE shift_id = ? 
      GROUP BY type
    ''',
      [shiftId],
    );

    double inSum = 0, outSum = 0;
    for (var row in movementData) {
      final type = row['type'].toString();
      final sum = (row['total_sum'] as num?)?.toDouble() ?? 0.0;
      if (type == 'IN') {
        inSum += sum;
      } else if (type == 'OUT') {
        outSum += sum;
      }
    }

    // Smenaning ochilish balansini olish
    final shiftRes = await db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
    );
    double openingCash = 0;
    if (shiftRes.isNotEmpty) {
      openingCash = (shiftRes.first['opening_cash'] as num?)?.toDouble() ?? 0.0;
    }

    // Chegirma statistikasi
    final discountStats = await _dbHelper.getDiscountStatsByShift(shiftId);

    // Xarajatlar
    final totalExpenses = await _dbHelper.getShiftExpenseTotal(shiftId);

    return ShiftSummary(
      totalCashSales: cash,
      totalCardSales: card,
      totalTerminalSales: terminal,
      totalDebtSales: debt,
      totalBonusSales: bonus,
      totalTransferSales: transfer,
      totalInMovements: inSum,
      totalOutMovements: outSum,
      expectedCashBalance: openingCash + cash + inSum - outSum,
      totalOrderDiscount: (discountStats['order_discount_total'] as num?)?.toDouble() ?? 0,
      totalItemDiscount:  (discountStats['item_discount_total']  as num?)?.toDouble() ?? 0,
      totalExpenses: totalExpenses,
    );
  }

  // --- Avtomatik smena sozlamalari (settings jadvali) ---

  /// Avtomatik smena bilan bog'liq sozlamalarni (kalit→qiymat) qaytaradi.
  Future<Map<String, String>> getAutoShiftSettings() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'settings',
      where:
          "key IN ('auto_shift_enabled', 'auto_shift_start', 'auto_shift_end', 'day_reset_time')",
    );
    return {
      for (final r in rows) r['key'] as String: (r['value'] as String? ?? ''),
    };
  }

  /// Avtomatik smena sozlamalarini saqlaydi (upsert).
  Future<void> saveAutoShiftSettings({
    required bool enabled,
    required String start,
    required String end,
    required String dayResetTime,
  }) async {
    final db = await _dbHelper.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['auto_shift_enabled', enabled ? '1' : '0'],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['auto_shift_start', start],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['day_reset_time', dayResetTime],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['auto_shift_end', end],
    );
  }

  /// Birinchi faol admin foydalanuvchi ID'sini qaytaradi; topilmasa 0 (tizim).
  Future<int> getFirstAdminUserId() async {
    final db = await _dbHelper.database;
    final adminRes = await db.query(
      'users',
      where: "role = 'admin' AND is_active = 1",
      limit: 1,
    );
    return adminRes.isNotEmpty ? (adminRes.first['id'] as int) : 0;
  }
}

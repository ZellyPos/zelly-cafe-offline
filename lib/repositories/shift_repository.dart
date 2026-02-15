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

  // --- Hisobotlar (Agregatsiya) ---

  /// Smena bo'yicha sotuvlar summasini olish
  Future<ShiftSummary> getShiftSalesSummary(int shiftId) async {
    final db = await _dbHelper.database;

    // To'lov turi bo'yicha sotuvlar
    final salesData = await db.rawQuery(
      '''
      SELECT payment_type, SUM(total) as total_sum 
      FROM orders 
      WHERE shift_id = ? AND status = 1
      GROUP BY payment_type
    ''',
      [shiftId],
    );

    double cash = 0, card = 0, debt = 0;
    for (var row in salesData) {
      final type = row['payment_type'].toString().toLowerCase();
      final sum = (row['total_sum'] as num?)?.toDouble() ?? 0.0;
      if (type.contains('naqd') || type.contains('cash'))
        cash += sum;
      else if (type.contains('karta') || type.contains('card'))
        card += sum;
      else if (type.contains('nasiya') || type.contains('debt'))
        debt += sum;
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
      if (type == 'IN')
        inSum += sum;
      else if (type == 'OUT')
        outSum += sum;
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

    return ShiftSummary(
      totalCashSales: cash,
      totalCardSales: card,
      totalDebtSales: debt,
      totalInMovements: inSum,
      totalOutMovements: outSum,
      expectedCashBalance: openingCash + cash + inSum - outSum,
    );
  }
}

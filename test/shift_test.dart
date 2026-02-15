import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tezzro/core/database_helper.dart';
import 'package:tezzro/core/services/shift_service.dart';
import 'package:tezzro/models/shift_models.dart';
import 'package:tezzro/models/order.dart';
import 'package:tezzro/repositories/shift_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.databasePathOverride = inMemoryDatabasePath;

  group('Smena Moduli Testlari', () {
    final shiftService = ShiftService.instance;
    final shiftRepo = ShiftRepository();
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      print('Setting up test...');
      final db = await dbHelper.database;
      print('Database opened.');
      await db.delete('shifts');
      print('Shifts deleted.');
      await db.delete('cash_movements');
      print('Movements deleted.');
      await db.delete('orders');
      print('Orders deleted.');
    });

    test('Smena ochish va yopish jarayoni', () async {
      // 1. Smena ochish
      final shiftId = await shiftService.openShift(
        100000.0,
        1,
      ); // 100k bilan ochish
      expect(shiftId, greaterThan(0));

      final activeShift = await shiftRepo.getOpenShift();
      expect(activeShift?.openingCash, 100000.0);
      expect(activeShift?.status, 0);

      // 2. Naqd pul harakati (Chiqim)
      await shiftService.addCashMovement(
        amount: 50000.0,
        type: 'OUT',
        reason: 'xarajat',
        note: 'Kantselyariya',
        userId: 1,
      );

      // 3. Simulyatsiya qilingan sotuv (Naqd)
      final order = Order(
        id: 'SHIFT-TEST-001',
        total: 250000.0,
        paymentType: 'Naqd',
        createdAt: DateTime.now(),
      );

      final db = await dbHelper.database;
      await db.insert('orders', {
        ...order.toMap(),
        'shift_id': shiftId,
        'status': 1, // To'langan
      });

      // 4. Smena hisobotini tekshirish
      final summary = await shiftRepo.getShiftSalesSummary(shiftId);
      expect(summary.totalCashSales, 250000.0);
      expect(summary.totalOutMovements, 50000.0);
      // Kutilayotgan: 100k (ochilish) + 250k (sotuv) - 50k (chiqim) = 300k
      expect(summary.expectedCashBalance, 300000.0);

      // 5. Smenani yopish
      await shiftService.closeShift(310000.0, 1, '10k ortiqcha chiqdi');

      final closedShift = await db.query(
        'shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
      );
      final shiftData = Shift.fromMap(closedShift.first);

      expect(shiftData.status, 1);
      expect(shiftData.difference, 10000.0);
    });

    test('Faqat bitta smena ochiq bo\'lishini tekshirish', () async {
      // Yangi smena ochish (oldingi testdan keyin smenalar yopilgan bo'lishi kerak)
      // Lekin testlar izolatsiyasi uchun db ni tozalash yoki boshqa yo'l tutish mumkin.
      // Bu yerda ochiq smena bo'lsa xatolik berishini tekshiramiz.
      await shiftService.openShift(0, 1);

      expect(() => shiftService.openShift(0, 1), throwsException);
    });
  });
}

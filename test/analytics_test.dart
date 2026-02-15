import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tezzro/core/database_helper.dart';
import 'package:tezzro/core/services/analytics_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Analitika Servisi Testlari', () {
    late Database db;

    setUp(() async {
      DatabaseHelper.databasePathOverride = inMemoryDatabasePath;
      db = await DatabaseHelper.instance.database;

      // Test ma'lumotlarini tozalash
      await db.delete('orders');
      await db.delete('order_items');
      await db.delete('waiters');

      // Test uchun ofitsiant qo'shish
      await db.insert('waiters', {
        'id': 1,
        'name': 'Test Ofitsiant',
        'type': 0,
        'value': 10,
      });

      // Test buyurtmalarini qo'shish
      final now = DateTime.now();

      // 1-buyurtma (Naqd)
      await db.insert('orders', {
        'id': 'ord1',
        'grand_total': 100000,
        'payment_type': 'Naqd',
        'status': 1,
        'waiter_id': 1,
        'service_fee': 10000,
        'created_at': now.toIso8601String(),
      });
      await db.insert('order_items', {
        'order_id': 'ord1',
        'product_id': 101,
        'product_name': 'Osh',
        'qty': 2,
        'price': 50000,
      });

      // 2-buyurtma (Karta)
      await db.insert('orders', {
        'id': 'ord2',
        'grand_total': 50000,
        'payment_type': 'Karta',
        'status': 1,
        'waiter_id': 1,
        'service_fee': 5000,
        'created_at': now.toIso8601String(),
      });
      await db.insert('order_items', {
        'order_id': 'ord2',
        'product_id': 102,
        'product_name': 'Choy',
        'qty': 5,
        'price': 10000,
      });

      AnalyticsService.instance.clearCache();
    });

    test('Kunlik sotuvlar hisoboti to\'g\'riligini tekshirish', () async {
      final start = DateTime.now().subtract(Duration(days: 1));
      final end = DateTime.now().add(Duration(days: 1));

      final sales = await AnalyticsService.instance.getDailySales(
        start: start,
        end: end,
      );

      expect(sales.length, 1);
      expect(sales.first.total, 150000);
      expect(sales.first.cash, 100000);
      expect(sales.first.card, 50000);
      expect(sales.first.ordersCount, 2);
    });

    test('Eng ko\'p sotilgan mahsulotlarni tekshirish', () async {
      final start = DateTime.now().subtract(Duration(days: 1));
      final end = DateTime.now().add(Duration(days: 1));

      final top = await AnalyticsService.instance.getTopProducts(
        start: start,
        end: end,
      );

      expect(top.length, 2);
      expect(top.first.productName, 'Choy'); // Qty=5 bo'lgani uchun 1-o'rinda
      expect(top.first.qty, 5);
      expect(top[1].productName, 'Osh');
      expect(top[1].qty, 2);
    });

    test('Ofitsiantlar samaradorligini tekshirish', () async {
      final start = DateTime.now().subtract(Duration(days: 1));
      final end = DateTime.now().add(Duration(days: 1));

      final perf = await AnalyticsService.instance.getWaiterPerformance(
        start: start,
        end: end,
      );

      expect(perf.length, 1);
      expect(perf.first.waiterName, 'Test Ofitsiant');
      expect(perf.first.revenue, 150000);
      expect(perf.first.serviceTotal, 15000);
      expect(perf.first.ordersCount, 2);
    });
  });
}

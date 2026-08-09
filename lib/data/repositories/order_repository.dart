import '../../core/database_helper.dart';
import '../../models/order.dart';

/// Buyurtmalar (`orders` / `order_items`) va ular bilan bog'liq stol holati
/// (`tables`) hamda zaxira (`products.quantity`) uchun **lokal** ma'lumotlar
/// qatlami.
///
/// Bu repozitoriy faqat SQLite bilan ishlaydi. Client rejimidagi HTTP so'rovlar,
/// WebSocket broadcast, chop etish va audit — bular provider (orkestratsiya)
/// darajasida qoladi. Shu bois metodlar tranzaksiya chegaralarini asl kod bilan
/// bir xil saqlaydi.
class OrderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── O'qish ──────────────────────────────────────────────────────────────

  /// Ochiq (`status = 0`) buyurtmani `id` bo'yicha oladi.
  Future<Map<String, dynamic>?> getOpenOrderById(String orderId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'orders',
      where: 'id = ? AND status = 0',
      whereArgs: [orderId],
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Stolning aktiv buyurtma ID'sini qaytaradi.
  Future<String?> getActiveOrderIdForTable(int tableId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'tables',
      columns: ['active_order_id'],
      where: 'id = ?',
      whereArgs: [tableId],
    );
    return res.isNotEmpty ? res.first['active_order_id'] as String? : null;
  }

  /// Buyurtma qatorlarini mahsulot ma'lumoti (nomi/narxi/kategoriyasi/zaxira)
  /// bilan JOIN qilib qaytaradi.
  Future<List<Map<String, dynamic>>> getOrderItemsWithProduct(
    String orderId,
  ) async {
    final db = await _dbHelper.database;
    return db.rawQuery(
      '''
      SELECT oi.*, p.name as product_name, p.price as product_price,
             p.category as product_category, p.quantity as product_quantity,
             p.no_service_charge
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''',
      [orderId],
    );
  }

  /// Buyurtmaning kunlik raqamini qaytaradi.
  Future<int?> getOrderDailyNumber(String orderId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'orders',
      columns: ['daily_number'],
      where: 'id = ?',
      whereArgs: [orderId],
    );
    return res.isNotEmpty ? res.first['daily_number'] as int? : null;
  }

  /// Kun uchun keyingi kunlik buyurtma raqamini hisoblaydi
  /// (`day_reset_time` sozlamasini hisobga oladi).
  Future<int> getNextDailyNumber() async {
    final db = await _dbHelper.database;
    final dayStart = await _dbHelper.getDayStartTime();
    final res = await db.rawQuery(
      'SELECT MAX(daily_number) as max_no FROM orders WHERE created_at >= ?',
      [dayStart.toIso8601String()],
    );
    if (res.isNotEmpty && res.first['max_no'] != null) {
      return (res.first['max_no'] as int) + 1;
    }
    return 1;
  }

  /// Standart ("Kassa") ofitsiant ID'sini qaytaradi.
  Future<int?> getDefaultWaiterId() => _dbHelper.getDefaultWaiterId();

  /// Buyurtmaga bog'langan stollarni (xona narxi hisobi uchun) qaytaradi.
  ///
  /// Yangi buyurtma hali DB'ga yozilmagan bo'lishi mumkin, shuning uchun
  /// [tableId] ham hisobga olinadi.
  Future<List<Map<String, dynamic>>> getLinkedTables({
    String? orderId,
    int? tableId,
  }) async {
    final db = await _dbHelper.database;
    if (orderId != null && tableId != null) {
      return db.query(
        'tables',
        where: 'active_order_id = ? OR id = ?',
        whereArgs: [orderId, tableId],
      );
    } else if (orderId != null) {
      return db.query('tables', where: 'active_order_id = ?', whereArgs: [orderId]);
    }
    return db.query('tables', where: 'id = ?', whereArgs: [tableId]);
  }

  // ── Yozish (oddiy) ─────────────────────────────────────────────────────

  /// Buyurtma yozuvini qo'shadi (map ko'rinishida).
  Future<void> insertOrder(Map<String, dynamic> orderMap) async {
    final db = await _dbHelper.database;
    await db.insert('orders', orderMap);
  }

  /// Buyurtmaning ofitsiantini yangilaydi.
  Future<void> updateOrderWaiter(String orderId, int? waiterId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'waiter_id': waiterId},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Buyurtmaning kunlik raqamini o'rnatadi.
  Future<void> updateOrderDailyNumber(String orderId, int dailyNo) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'daily_number': dailyNo},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Stolning holati va aktiv buyurtma bog'liqligini yangilaydi.
  Future<void> updateTableLink(
    int tableId, {
    required int status,
    String? activeOrderId,
    bool clearOrder = false,
  }) async {
    final db = await _dbHelper.database;
    final data = <String, dynamic>{'status': status};
    if (clearOrder || activeOrderId != null) {
      data['active_order_id'] = activeOrderId;
    }
    await db.update('tables', data, where: 'id = ?', whereArgs: [tableId]);
  }

  /// Buyurtma sarlavhasini (jami/chegirma/xona/xizmat) yangilaydi.
  Future<void> updateOrderHeader(
    String orderId, {
    required double foodTotal,
    required double roomTotal,
    required double serviceTotal,
    required double grandTotal,
    required int? waiterId,
    required String? discountType,
    required double discountValue,
    required String? discountNote,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {
        'total': grandTotal,
        'food_total': foodTotal,
        'room_charge': roomTotal,
        'room_total': roomTotal,
        'service_total': serviceTotal,
        'grand_total': grandTotal,
        'waiter_id': waiterId,
        'discount_type': discountType,
        'discount_value': discountValue,
        'discount_note': discountNote,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Buyurtma qatorlarini bitta tranzaksiyada to'liq almashtiradi
  /// (avval o'chiradi, keyin [itemRows]ni qo'shadi).
  Future<void> replaceOrderItems(
    String orderId,
    List<Map<String, dynamic>> itemRows,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final row in itemRows) {
        await txn.insert('order_items', row);
      }
    });
  }

  /// Buyurtmaning to'lovlarini (`order_payments`) qaytaradi.
  Future<List<Map<String, dynamic>>> getOrderPayments(String orderId) {
    return _dbHelper.getOrderPayments(orderId);
  }

  /// Buyurtmaga bitta to'lov yozuvini qo'shadi.
  Future<void> insertOrderPayment(Map<String, dynamic> payment) {
    return _dbHelper.insertOrderPayment(payment);
  }

  /// Buyurtmaga "hisob so'raldi" belgisini qo'yadi.
  Future<void> markBillRequested(String orderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {
        'bill_requested': 1,
        'bill_requested_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Oddiy zaxira kuzatuvi: sotilgan mahsulotlar sonini kamaytiradi
  /// (`quantity IS NOT NULL` bo'lganlar uchun).
  Future<void> decrementProductStock(List<OrderItem> items) async {
    final db = await _dbHelper.database;
    for (final item in items) {
      await db.rawUpdate(
        'UPDATE products '
        'SET quantity = MAX(0, COALESCE(quantity, 0) - ?) '
        'WHERE id = ? AND quantity IS NOT NULL',
        [item.qty, item.productId],
      );
    }
  }

  // ── Checkout (lokal, katta tranzaksiya) ────────────────────────────────

  /// To'lovni yakunlaydi: xona narxini bog'langan stollardan hisoblaydi,
  /// buyurtmani yangilaydi/qo'shadi, qatorlarni almashtiradi va stollarni
  /// bo'shatadi. Barchasi bitta tranzaksiyada.
  ///
  /// Hisoblangan summalarni (`roomCharge`, `serviceFee`, `foodTotal`,
  /// `grandTotal`) qaytaradi.
  ///
  /// Eslatma: kunlik raqam ([preDailyNo]) tranzaksiyadan TASHQARIDA olinishi
  /// kerak — aks holda `sqflite_common_ffi` da deadlock bo'ladi.
  Future<Map<String, double>> commitCheckout({
    required String orderId,
    required bool isExistingOrder,
    required int? currentTableId,
    required int? resolvedTableId,
    required int? resolvedLocationId,
    required int? resolvedWaiterId,
    required int orderType,
    required String paymentType,
    required double paidAmount,
    required double change,
    required int? preDailyNo,
    required int? activeShiftId,
    required String? cleanedNote,
    required String? discountType,
    required double discountValue,
    required String? discountNote,
    required double foodTotal,
    required double discountAmount,
    required double serviceFee,
    required double totalForServiceCharge,
    required DateTime? openedAt,
    required List<OrderItem> items,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      double totalRoomCharge = 0;
      final now = DateTime.now();

      // 1. Buyurtmaga bog'langan barcha stollarni topib, narxlarini yig'amiz
      final allLinkedTablesRes = await txn.query(
        'tables',
        where: currentTableId != null
            ? 'active_order_id = ? OR id = ?'
            : 'active_order_id = ?',
        whereArgs: currentTableId != null
            ? [orderId, currentTableId]
            : [orderId],
      );

      for (final tableMap in allLinkedTablesRes) {
        final int pricingType = tableMap['pricing_type'] as int? ?? 0;
        final double hourlyRate = (tableMap['hourly_rate'] as num? ?? 0).toDouble();
        final double fixedAmount = (tableMap['fixed_amount'] as num? ?? 0).toDouble();
        final double servicePercentage =
            (tableMap['service_percentage'] as num? ?? 0).toDouble();

        if (pricingType == 1) {
          final openedAtLocal = openedAt ?? now;
          final duration = now.difference(openedAtLocal);
          final hours = duration.inMinutes / 60.0;
          totalRoomCharge += hours * hourlyRate;
        } else if (pricingType == 2) {
          totalRoomCharge += fixedAmount;
        } else if (pricingType == 3) {
          totalRoomCharge += (totalForServiceCharge * servicePercentage / 100);
        }
      }
      final double roomCharge = totalRoomCharge;

      final double grandTotal = (foodTotal - discountAmount + roomCharge + serviceFee)
          .clamp(0.0, double.infinity);

      if (isExistingOrder) {
        await txn.update(
          'orders',
          {
            'total': grandTotal,
            'payment_type': paymentType,
            'status': 1,
            'waiter_id': resolvedWaiterId,
            'closed_at': now.toIso8601String(),
            'room_charge': roomCharge,
            'paid_amount': paidAmount,
            'receipt_change': change,
            'food_total': foodTotal,
            'room_total': roomCharge,
            'service_total': serviceFee,
            'grand_total': grandTotal,
            'daily_number': preDailyNo,
            'shift_id': activeShiftId,
            'discount_type': discountType,
            'discount_value': discountValue,
            'discount_note': discountNote,
            'note': cleanedNote,
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
      } else {
        final order = Order(
          id: orderId,
          total: grandTotal,
          paymentType: paymentType,
          createdAt: now,
          orderType: orderType,
          tableId: resolvedTableId,
          waiterId: resolvedWaiterId,
          locationId: resolvedLocationId,
          status: 1,
          paidAmount: paidAmount,
          change: change,
          foodTotal: foodTotal,
          roomTotal: roomCharge,
          serviceTotal: serviceFee,
          grandTotal: grandTotal,
          openedAt: now,
          closedAt: now,
          dailyNumber: preDailyNo,
          shiftId: activeShiftId,
          note: cleanedNote,
        );
        await txn.insert('orders', order.toMap());
      }

      if (isExistingOrder) {
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      }

      for (final item in items) {
        await txn.insert('order_items', item.toMap());
      }

      if (resolvedTableId != null || currentTableId != null) {
        await txn.update(
          'tables',
          {'status': 0, 'active_order_id': null},
          where: 'active_order_id = ?',
          whereArgs: [orderId],
        );
      }

      return {
        'roomCharge': roomCharge,
        'serviceFee': serviceFee,
        'foodTotal': foodTotal,
        'grandTotal': grandTotal,
      };
    });
  }

  // ── Bekor qilish / ko'chirish / birlashtirish (lokal tranzaksiyalar) ───

  /// Buyurtmani va uning qatorlarini o'chiradi, bog'langan stollarni bo'shatadi.
  Future<void> cancelOrderLocal(String orderId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
      await txn.update(
        'tables',
        {'status': 0, 'active_order_id': null},
        where: 'active_order_id = ?',
        whereArgs: [orderId],
      );
    });
  }

  /// Buyurtmani yangi stolga ko'chiradi (eski stolni bo'shatib, yangisini band
  /// qiladi).
  Future<void> moveOrderLocal({
    required String orderId,
    required int newTableId,
    required int newLocationId,
    int? oldTableId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {'table_id': newTableId, 'location_id': newLocationId},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (oldTableId != null) {
        await txn.update(
          'tables',
          {'status': 0, 'active_order_id': null},
          where: 'id = ?',
          whereArgs: [oldTableId],
        );
      }

      await txn.update(
        'tables',
        {'status': 1, 'active_order_id': orderId},
        where: 'id = ?',
        whereArgs: [newTableId],
      );
    });
  }

  /// Ikki stolni birlashtiradi. Manba buyurtma qatorlarini maqsad buyurtmaga
  /// o'tkazadi va ikkala stolni yakuniy buyurtmaga bog'laydi.
  ///
  /// Qaytaradi: yakuniy buyurtma ID'si, yoki birlashtirish mumkin bo'lmasa
  /// `null` (ikkala stol ham bo'sh yoki topilmadi).
  Future<String?> mergeTablesLocal(
    int sourceTableId,
    int targetTableId,
  ) async {
    final db = await _dbHelper.database;

    final sourceTableRes = await db.query(
      'tables',
      where: 'id = ?',
      whereArgs: [sourceTableId],
    );
    final targetTableRes = await db.query(
      'tables',
      where: 'id = ?',
      whereArgs: [targetTableId],
    );

    if (sourceTableRes.isEmpty || targetTableRes.isEmpty) return null;

    final String? sourceOrderId = sourceTableRes.first['active_order_id'] as String?;
    final String? targetOrderId = targetTableRes.first['active_order_id'] as String?;

    if (sourceOrderId == null && targetOrderId == null) {
      return null; // Ikkalasi ham bo'sh — birlashtirishga narsa yo'q
    }

    late String finalOrderId;
    await db.transaction((txn) async {
      if (targetOrderId != null) {
        finalOrderId = targetOrderId;
        if (sourceOrderId != null && sourceOrderId != targetOrderId) {
          // Manbadan maqsadga qatorlarni KO'CHIRISH
          final sourceItems = await txn.query(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [sourceOrderId],
          );
          for (final item in sourceItems) {
            final existing = await txn.query(
              'order_items',
              where: 'order_id = ? AND product_id = ?',
              whereArgs: [finalOrderId, item['product_id']],
            );

            if (existing.isNotEmpty) {
              final srcPrintedQty =
                  (item['printed_qty'] as num? ?? item['qty'] as num).toDouble();
              await txn.rawUpdate(
                'UPDATE order_items SET qty = qty + ?, printed_qty = printed_qty + ? WHERE id = ?',
                [item['qty'], srcPrintedQty, existing.first['id']],
              );
            } else {
              await txn.insert('order_items', {
                'order_id': finalOrderId,
                'product_id': item['product_id'],
                'qty': item['qty'],
                'price': item['price'],
                'bundle_items_json': item['bundle_items_json'],
                'printed_qty': item['printed_qty'] ?? item['qty'],
              });
            }
          }
          await txn.delete('order_items', where: 'order_id = ?', whereArgs: [sourceOrderId]);
          await txn.delete('orders', where: 'id = ?', whereArgs: [sourceOrderId]);
        }
      } else {
        // Maqsad bo'sh, manbada buyurtma bor — maqsadni manba buyurtmaga bog'laymiz
        finalOrderId = sourceOrderId!;
      }

      // Ikkala stolni bir buyurtmaga bog'lash
      await txn.update(
        'tables',
        {'status': 1, 'active_order_id': finalOrderId},
        where: 'id = ? OR id = ?',
        whereArgs: [sourceTableId, targetTableId],
      );
    });

    return finalOrderId;
  }
}

import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/inventory_models.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../repositories/inventory_repository.dart';
import '../database_helper.dart';
import './audit_service.dart';

/// Pishirish paytida xomashyo yetmasa tashlanadi.
///
/// [shortages] — har bir yetishmayotgan xomashyo: nom, kerak, mavjud, birlik.
class InsufficientStockException implements Exception {
  final List<({String name, double need, double onHand, String unit})>
  shortages;

  InsufficientStockException(this.shortages);

  /// Foydalanuvchiga ko'rsatiladigan xabar.
  String get message {
    final lines = shortages.map(
      (s) =>
          '${s.name}: kerak ${_fmt(s.need)} ${s.unit}, '
          'mavjud ${_fmt(s.onHand)} ${s.unit}',
    );
    return 'Xomashyo yetarli emas:\n${lines.join('\n')}';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  String toString() => message;
}

/// Ombor biznes-logikasi.
///
/// **Yangi model (2026-08):** xomashyo faqat **Pishirish** (`produce`)
/// paytida chegiriladi; **Sotuvda** esa faqat tayyor mahsulot soni kamayadi
/// (`processOrderPaid`). Bu ikki marta chegirishning oldini oladi.
class InventoryService {
  final InventoryRepository _repo = InventoryRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static final InventoryService instance = InventoryService._internal();
  InventoryService._internal();

  // --- Purchase / Waste / Adjust ---

  Future<void> purchaseIn({
    required int ingredientId,
    required double qty,
    String? note,
    int? userId,
  }) async {
    final movement = StockMovement(
      ingredientId: ingredientId,
      type: MovementType.IN,
      qty: qty,
      reason: 'purchase',
      note: note,
      createdAt: DateTime.now(),
      createdBy: userId,
    );
    await _repo.addStockMovement(movement, null);
  }

  Future<void> wasteOut({
    required int ingredientId,
    required double qty,
    String? reason,
    int? userId,
  }) async {
    final movement = StockMovement(
      ingredientId: ingredientId,
      type: MovementType.OUT,
      qty: qty,
      reason: reason ?? 'waste',
      createdAt: DateTime.now(),
      createdBy: userId,
    );
    await _repo.addStockMovement(movement, null);
  }

  Future<void> adjustStock({
    required int ingredientId,
    required double realQty,
    String? note,
    int? userId,
  }) async {
    final movement = StockMovement(
      ingredientId: ingredientId,
      type: MovementType.ADJUST,
      qty: realQty,
      reason: 'adjustment',
      note: note,
      createdAt: DateTime.now(),
      createdBy: userId,
    );
    await _repo.addStockMovement(movement, null);
  }

  // --- Sotuv (Checkout) ---
  //
  // YANGI MODEL: sotuvda faqat TAYYOR MAHSULOT soni kamayadi. Xomashyo
  // sotuvda EMAS, "Pishirish" (produce) paytida chegiriladi — aks holda ikki
  // marta chegirilardi.

  Future<void> processOrderPaid(Order order, [Transaction? txn]) async {
    final executor = txn ?? (await _dbHelper.database);

    if (txn != null) {
      await _processOrderPaidLogic(order, txn);
    } else {
      await (executor as Database).transaction((newTxn) async {
        await _processOrderPaidLogic(order, newTxn);
      });
    }
  }

  Future<void> _processOrderPaidLogic(Order order, Transaction txn) async {
    // Ikki marta chegirishdan himoya
    final existingFlag = await _repo.getInventoryFlag(order.id, txn);
    if (existingFlag != null && existingFlag.deducted) {
      return; // Allaqachon qayta ishlangan
    }

    for (final item in order.items) {
      final productMap = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [item.productId],
      );
      if (productMap.isEmpty) continue;
      final product = Product.fromMap(productMap.first);

      if (product.isSet && item.bundleItemsJson != null) {
        // To'plam (bundle) — snapshot bo'yicha
        final List<dynamic> bundleList = jsonDecode(item.bundleItemsJson!);
        for (final bMap in bundleList) {
          final bItem = BundleItem.fromMap(bMap);
          await _sellFinished(
            txn,
            bItem.productId,
            bItem.quantity * item.qty,
            order.id,
          );
        }
      } else {
        await _sellFinished(txn, item.productId, item.qty.toDouble(), order.id);
      }
    }

    await _repo.setInventoryFlag(
      OrderInventoryFlag(
        orderId: order.id,
        deducted: true,
        deductedAt: DateTime.now(),
      ),
      txn,
    );
  }

  /// Sotuvda tayyor mahsulot sonini kamaytiradi (xomashyoga tegmaydi).
  Future<void> _sellFinished(
    Transaction txn,
    int productId,
    double qty,
    String orderId,
  ) async {
    await txn.rawUpdate(
      'UPDATE products SET quantity = COALESCE(quantity, 0) - ? WHERE id = ?',
      [qty, productId],
    );
    await txn.insert('product_movements', {
      'product_id': productId,
      'type': 'SALE',
      'qty': qty,
      'ref_table': 'orders',
      'ref_id': orderId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // --- Pishirish (PRODUCTION) ---
  //
  // Tayyor mahsulot tayyorlanadi: retsept bo'yicha xomashyo chegiriladi va
  // tayyor mahsulot soni oshadi. Barchasi bitta tranzaksiyada.

  /// [allowNegative] `false` bo'lsa (default) xomashyo yetmasa
  /// [InsufficientStockException] tashlanadi va hech narsa yozilmaydi.
  Future<void> produce(
    List<({int productId, double count})> items, {
    int? userId,
    bool allowNegative = false,
  }) async {
    if (items.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. Barcha mahsulotlar bo'yicha kerakli xomashyoni yig'ish.
      //    (Bir xomashyo bir necha retseptda uchrashi mumkin — jamlanadi.)
      final needByIngredient = <int, double>{};
      final productNeeds =
          <int, Map<int, double>>{}; // productId -> {ingId: need}

      for (final pi in items) {
        final perProduct = <int, double>{};
        final recipeMaps = await txn.query(
          'recipes',
          where: 'product_id = ?',
          whereArgs: [pi.productId],
        );
        if (recipeMaps.isNotEmpty) {
          final recipeId = recipeMaps.first['id'];
          final yieldQty =
              (recipeMaps.first['yield_qty'] as num?)?.toDouble() ?? 1.0;
          final divisor = yieldQty == 0 ? 1.0 : yieldQty;

          final itemMaps = await txn.query(
            'recipe_items',
            where: 'recipe_id = ?',
            whereArgs: [recipeId],
          );
          for (final iMap in itemMaps) {
            final ingredientId = iMap['ingredient_id'] as int;
            final perYield = (iMap['qty'] as num).toDouble();
            final need = (perYield / divisor) * pi.count;
            perProduct[ingredientId] = (perProduct[ingredientId] ?? 0) + need;
            needByIngredient[ingredientId] =
                (needByIngredient[ingredientId] ?? 0) + need;
          }
        }
        productNeeds[pi.productId] = perProduct;
      }

      // 2. Yetarlilikni tekshirish — yozishdan OLDIN (tranzaksiya rollback).
      if (!allowNegative && needByIngredient.isNotEmpty) {
        final ids = needByIngredient.keys.join(',');
        final rows = await txn.rawQuery('''
          SELECT i.id, i.name, i.base_unit, COALESCE(s.on_hand, 0) AS on_hand
          FROM ingredients i
          LEFT JOIN ingredient_stock s ON s.ingredient_id = i.id
          WHERE i.id IN ($ids)
        ''');
        final shortages =
            <({String name, double need, double onHand, String unit})>[];
        for (final row in rows) {
          final id = row['id'] as int;
          final onHand = (row['on_hand'] as num).toDouble();
          final need = needByIngredient[id] ?? 0;
          if (need - onHand > 1e-9) {
            shortages.add((
              name: row['name'] as String,
              need: need,
              onHand: onHand,
              unit: (row['base_unit'] as String?) ?? '',
            ));
          }
        }
        if (shortages.isNotEmpty) throw InsufficientStockException(shortages);
      }

      // 3. Xomashyoni chegirish + tayyor sonni oshirish.
      for (final pi in items) {
        for (final entry in (productNeeds[pi.productId] ?? {}).entries) {
          await txn.rawUpdate(
            'UPDATE ingredient_stock SET on_hand = on_hand - ?, updated_at = ? WHERE ingredient_id = ?',
            [entry.value, now, entry.key],
          );
          await txn.insert('stock_movements', {
            'ingredient_id': entry.key,
            'type': 'OUT',
            'qty': entry.value,
            'reason': 'production',
            'ref_table': 'products',
            'ref_id': pi.productId.toString(),
            'created_at': now,
            'created_by': userId,
          });
        }

        await txn.rawUpdate(
          'UPDATE products SET quantity = COALESCE(quantity, 0) + ? WHERE id = ?',
          [pi.count, pi.productId],
        );
        await txn.insert('product_movements', {
          'product_id': pi.productId,
          'type': 'PRODUCE',
          'qty': pi.count,
          'created_at': now,
          'created_by': userId,
        });
      }
    });
  }

  // --- Refund / Void (bekor qilish) ---
  //
  // Sotuvda faqat tayyor son kamaygani uchun, qaytarishda ham faqat tayyor son
  // oshadi (xomashyo qaytarilmaydi).

  Future<void> reverseOrderPaid(Order order) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // txn uzatilishi shart — aks holda tranzaksiya ichida yangi ulanish
      // so'raladi va deadlock bo'ladi.
      final flag = await _repo.getInventoryFlag(order.id, txn);
      if (flag == null || !flag.deducted || flag.reversed) {
        return; // Qaytariladigan narsa yo'q yoki allaqachon qaytarilgan
      }

      for (final item in order.items) {
        final productMap = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        if (productMap.isEmpty) continue;
        final product = Product.fromMap(productMap.first);

        if (product.isSet && item.bundleItemsJson != null) {
          final List<dynamic> bundleList = jsonDecode(item.bundleItemsJson!);
          for (final bMap in bundleList) {
            final bItem = BundleItem.fromMap(bMap);
            await _returnFinished(
              txn,
              bItem.productId,
              bItem.quantity * item.qty,
              order.id,
            );
          }
        } else {
          await _returnFinished(
            txn,
            item.productId,
            item.qty.toDouble(),
            order.id,
          );
        }
      }

      await txn.update(
        'order_inventory_flags',
        {'reversed': 1, 'reversed_at': DateTime.now().toIso8601String()},
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      AuditService.instance.logAction(
        action: 'refund_inventory',
        entity: 'order',
        entityId: order.id,
        after: {'items_count': order.items.length},
      );
    });
  }

  Future<void> _returnFinished(
    Transaction txn,
    int productId,
    double qty,
    String orderId,
  ) async {
    await txn.rawUpdate(
      'UPDATE products SET quantity = COALESCE(quantity, 0) + ? WHERE id = ?',
      [qty, productId],
    );
    await txn.insert('product_movements', {
      'product_id': productId,
      'type': 'ADJUST',
      'qty': qty,
      'ref_table': 'orders',
      'ref_id': orderId,
      'note': 'refund',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

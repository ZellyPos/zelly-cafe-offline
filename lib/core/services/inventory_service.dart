import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/inventory_models.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../repositories/inventory_repository.dart';
import '../database_helper.dart';
import './audit_service.dart';

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

  // --- Checkout Processing (CRITICAL) ---

  Future<void> processOrderPaid(Order order) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Guard against double-deduction
      final existingFlag = await _repo.getInventoryFlag(order.id);
      if (existingFlag != null && existingFlag.deducted) {
        return; // Already processed
      }

      for (var item in order.items) {
        // Load product with inventory settings
        final productMap = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        if (productMap.isEmpty) continue;

        final product = Product.fromMap(productMap.first);

        if (product.isSet && item.bundleItemsJson != null) {
          // Process bundle as snapshot
          final List<dynamic> bundleList = jsonDecode(item.bundleItemsJson!);
          for (var bMap in bundleList) {
            final bItem = BundleItem.fromMap(bMap);
            // Components of bundle are always products
            final subProductMap = await txn.query(
              'products',
              where: 'id = ?',
              whereArgs: [bItem.productId],
            );
            if (subProductMap.isNotEmpty) {
              final subProduct = Product.fromMap(subProductMap.first);
              await _deductProductStock(
                txn,
                subProduct,
                bItem.quantity * item.qty,
                order.id,
              );
            }
          }
        } else {
          // Process direct product
          await _deductProductStock(
            txn,
            product,
            item.qty.toDouble(),
            order.id,
          );
        }
      }

      // 2. Set flag
      await _repo.setInventoryFlag(
        OrderInventoryFlag(
          orderId: order.id,
          deducted: true,
          deductedAt: DateTime.now(),
        ),
        txn,
      );
    });
  }

  Future<void> _deductProductStock(
    Transaction txn,
    Product product,
    double qty,
    String orderId,
  ) async {
    if (product.trackType == 1) {
      // Retail Stock
      await _handleRetailDeduction(txn, product, qty);
    } else if (product.trackType == 2) {
      // Recipe Based
      await _handleRecipeDeduction(txn, product, qty, orderId);
    }
  }

  Future<void> _handleRetailDeduction(
    Transaction txn,
    Product product,
    double qty,
  ) async {
    // Check stock if negative not allowed
    if (!product.allowNegativeStock) {
      final currentQty = product.quantity ?? 0;
      if (currentQty < qty) {
        throw Exception('Mahsulot yetarli emas: ${product.name}');
      }
    }

    await txn.rawUpdate(
      'UPDATE products SET quantity = COALESCE(quantity, 0) - ? WHERE id = ?',
      [qty, product.id],
    );
  }

  Future<void> _handleRecipeDeduction(
    Transaction txn,
    Product product,
    double qty,
    String orderId,
  ) async {
    final recipeMaps = await txn.query(
      'recipes',
      where: 'product_id = ?',
      whereArgs: [product.id],
    );
    if (recipeMaps.isEmpty) return;

    final recipeId = recipeMaps.first['id'];
    final itemMaps = await txn.query(
      'recipe_items',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );

    for (var iMap in itemMaps) {
      final ingredientId = iMap['ingredient_id'];
      final requiredPerYield = (iMap['qty'] as num).toDouble();
      final yieldQty = (recipeMaps.first['yield_qty'] as num).toDouble();

      final totalRequired = (requiredPerYield / yieldQty) * qty;

      // Check ingredient stock (optional global check can be added here)
      // Here we assume allowNegativeStock on product might not apply to ingredients unless we add it

      // Update ingredient_stock
      await txn.rawUpdate(
        'UPDATE ingredient_stock SET on_hand = on_hand - ?, updated_at = ? WHERE ingredient_id = ?',
        [totalRequired, DateTime.now().toIso8601String(), ingredientId],
      );

      // Log movement
      await txn.insert('stock_movements', {
        'ingredient_id': ingredientId,
        'type': MovementType.OUT.name,
        'qty': totalRequired,
        'reason': 'sale',
        'ref_table': 'orders',
        'ref_id': orderId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // --- Refund / Void Handling ---

  Future<void> reverseOrderPaid(Order order) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final flag = await _repo.getInventoryFlag(order.id);
      if (flag == null || !flag.deducted || flag.reversed) {
        return; // Nothing to reverse or already reversed
      }

      for (var item in order.items) {
        final productMap = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        if (productMap.isEmpty) continue;
        final product = Product.fromMap(productMap.first);

        if (product.isSet && item.bundleItemsJson != null) {
          final List<dynamic> bundleList = jsonDecode(item.bundleItemsJson!);
          for (var bMap in bundleList) {
            final bItem = BundleItem.fromMap(bMap);
            final subProductMap = await txn.query(
              'products',
              where: 'id = ?',
              whereArgs: [bItem.productId],
            );
            if (subProductMap.isNotEmpty) {
              final subProduct = Product.fromMap(subProductMap.first);
              await _reverseProductStock(
                txn,
                subProduct,
                bItem.quantity * item.qty,
                order.id,
              );
            }
          }
        } else {
          await _reverseProductStock(
            txn,
            product,
            item.qty.toDouble(),
            order.id,
          );
        }
      }

      // Update flag
      await txn.update(
        'order_inventory_flags',
        {'reversed': 1, 'reversed_at': DateTime.now().toIso8601String()},
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      // Audit: Ombor qaytarilishi (Refund/Return)
      AuditService.instance.logAction(
        action: 'refund_inventory',
        entity: 'order',
        entityId: order.id,
        after: {'items_count': order.items.length},
      );
    });
  }

  Future<void> _reverseProductStock(
    Transaction txn,
    Product product,
    double qty,
    String orderId,
  ) async {
    if (product.trackType == 1) {
      // Retail
      await txn.rawUpdate(
        'UPDATE products SET quantity = COALESCE(quantity, 0) + ? WHERE id = ?',
        [qty, product.id],
      );
    } else if (product.trackType == 2) {
      // Recipe
      // Return ingredients
      final movements = await txn.query(
        'stock_movements',
        where: 'ref_table = ? AND ref_id = ? AND type = ?',
        whereArgs: ['orders', orderId, MovementType.OUT.name],
      );

      for (var mov in movements) {
        final ingredientId = mov['ingredient_id'];
        final deductibleQty = (mov['qty'] as num).toDouble();

        await txn.rawUpdate(
          'UPDATE ingredient_stock SET on_hand = on_hand + ?, updated_at = ? WHERE ingredient_id = ?',
          [deductibleQty, DateTime.now().toIso8601String(), ingredientId],
        );

        await txn.insert('stock_movements', {
          'ingredient_id': ingredientId,
          'type': MovementType.RETURN.name,
          'qty': deductibleQty,
          'reason': 'refund',
          'ref_table': 'orders',
          'ref_id': orderId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }
}

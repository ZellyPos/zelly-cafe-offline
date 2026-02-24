import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tezzro/core/database_helper.dart';
import 'package:tezzro/core/services/inventory_service.dart';
import 'package:tezzro/models/inventory_models.dart';
import 'package:tezzro/models/order.dart';
import 'package:tezzro/repositories/inventory_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Inventory Module Tests', () {
    final invRepo = InventoryRepository();
    final invService = InventoryService.instance;
    final dbHelper = DatabaseHelper.instance;

    test('End-to-end Inventory Flow', () async {
      DatabaseHelper.databasePathOverride = inMemoryDatabasePath;
      // 1. Setup Ingredients
      final meatId = await invRepo.insertIngredient(
        Ingredient(name: 'Go\'sht', baseUnit: 'g', minStock: 1000),
      );

      final breadId = await invRepo.insertIngredient(
        Ingredient(name: 'Non', baseUnit: 'pcs', minStock: 10),
      );

      // 2. Setup Products
      final burgerId = await dbHelper.insert('products', {
        'name': 'Burger',
        'price': 25000,
        'category': 'Food',
        'track_type': 2, // Recipe Based
        'is_active': 1,
      });

      final colaId = await dbHelper.insert('products', {
        'name': 'Cola 0.5',
        'price': 7000,
        'category': 'Drinks',
        'track_type': 1, // Retail Stock
        'quantity': 50.0,
        'is_active': 1,
      });

      // 3. Create Recipe
      await invRepo.upsertRecipe(
        Recipe(
          productId: burgerId,
          yieldQty: 1.0,
          items: [
            RecipeItem(recipeId: 0, ingredientId: meatId, qty: 150),
            RecipeItem(recipeId: 0, ingredientId: breadId, qty: 1),
          ],
        ),
      );

      // 4. Stock Purchase
      await invService.purchaseIn(ingredientId: meatId, qty: 5000);
      await invService.purchaseIn(ingredientId: breadId, qty: 100);

      var meatStock = await invRepo.getIngredientStock(meatId);
      expect(meatStock?.onHand, 5000);

      // 5. Process Order
      final order = Order(
        id: 'ORDER-VERIFY-001',
        total: 57000,
        paymentType: 'Cash',
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            orderId: 'ORDER-VERIFY-001',
            productId: burgerId,
            qty: 2,
            price: 25000,
          ),
          OrderItem(
            orderId: 'ORDER-VERIFY-001',
            productId: colaId,
            qty: 1,
            price: 7000,
          ),
        ],
      );

      await invService.processOrderPaid(order);

      // 6. Verify Deductions
      final updatedMeat = await invRepo.getIngredientStock(meatId);
      final updatedBread = await invRepo.getIngredientStock(breadId);

      final db = await dbHelper.database;
      final colaRes = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [colaId],
      );
      final colaQty = (colaRes.first['quantity'] as num).toDouble();

      expect(updatedMeat?.onHand, 4700); // 5000 - 300
      expect(updatedBread?.onHand, 98); // 100 - 2
      expect(colaQty, 49); // 50 - 1

      // 7. Test Reversal
      await invService.reverseOrderPaid(order);

      final revMeat = await invRepo.getIngredientStock(meatId);
      final colaResRev = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [colaId],
      );
      final colaQtyRev = (colaResRev.first['quantity'] as num).toDouble();

      expect(revMeat?.onHand, 5000);
      expect(colaQtyRev, 50);
    });
  });
}

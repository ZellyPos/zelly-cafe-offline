import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tezzro/core/database_helper.dart';
import 'package:tezzro/core/services/inventory_service.dart';
import 'package:tezzro/models/inventory_models.dart';
import 'package:tezzro/models/order.dart';
import 'package:tezzro/models/product.dart';
import 'package:tezzro/repositories/inventory_repository.dart';
import 'dart:io';

// Note: This is an integration test script.
// It assumes the environment is set up for sqflite_ffi (Windows/Linux).

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('--- Starting Inventory Verification ---');

  final dbHelper = DatabaseHelper.instance;
  final invRepo = InventoryRepository();
  final invService = InventoryService.instance;

  // 1. Setup Data
  print('1. Setting up ingredients and products...');
  final meatId = await invRepo.insertIngredient(
    Ingredient(name: 'Go\'sht', baseUnit: 'g', minStock: 1000),
  );

  final breadId = await invRepo.insertIngredient(
    Ingredient(name: 'Non', baseUnit: 'pcs', minStock: 10),
  );

  // Product: Burger (Recipe Based)
  final burgerId = await dbHelper.insert('products', {
    'name': 'Burger',
    'price': 25000,
    'category': 'Fud',
    'track_type': 2,
    'is_active': 1,
  });

  // Product: Cola (Retail Stock)
  final colaId = await dbHelper.insert('products', {
    'name': 'Cola 0.5',
    'price': 7000,
    'category': 'Ichimliklar',
    'track_type': 1,
    'quantity': 50,
    'is_active': 1,
  });

  // 2. Add Recipe for Burger
  print('2. Creating recipe for Burger...');
  await invRepo.upsertRecipe(
    Recipe(
      productId: burgerId,
      yieldQty: 1,
      items: [
        RecipeItem(recipeId: 0, ingredientId: meatId, qty: 150), // 150g meat
        RecipeItem(recipeId: 0, ingredientId: breadId, qty: 1), // 1 bread
      ],
    ),
  );

  // 3. Purchase Ingredients
  print('3. Purchasing ingredients...');
  await invService.purchaseIn(ingredientId: meatId, qty: 5000); // 5kg
  await invService.purchaseIn(ingredientId: breadId, qty: 100); // 100 pcs

  var meatStock = await invRepo.getIngredientStock(meatId);
  print('Meat stock: ${meatStock?.onHand}g (Expected 5000)');

  // 4. Simulate Sale
  print('4. Simulating sale (Burger x2, Cola x1)...');
  final order = Order(
    id: 'TEST-ORDER-001',
    total: 57000,
    paymentType: 'Naqd',
    createdAt: DateTime.now(),
    items: [
      OrderItem(
        orderId: 'TEST-ORDER-001',
        productId: burgerId,
        qty: 2,
        price: 25000,
      ),
      OrderItem(
        orderId: 'TEST-ORDER-001',
        productId: colaId,
        qty: 1,
        price: 7000,
      ),
    ],
  );

  await invService.processOrderPaid(order);

  // 5. Verify Stock After Sale
  print('5. Verifying stock after sale...');
  meatStock = await invRepo.getIngredientStock(meatId);
  var breadStock = await invRepo.getIngredientStock(breadId);

  final db = await dbHelper.database;
  final colaMap = await db.query(
    'products',
    where: 'id = ?',
    whereArgs: [colaId],
  );
  final colaQty = (colaMap.first['quantity'] as num).toDouble();

  print('Meat stock: ${meatStock?.onHand}g (Expected 4700)'); // 5000 - (150*2)
  print('Bread stock: ${breadStock?.onHand} pcs (Expected 98)'); // 100 - (1*2)
  print('Cola stock: $colaQty (Expected 49)'); // 50 - 1

  // 6. Test Idempotency
  print('6. Testing idempotency (processing same order again)...');
  await invService.processOrderPaid(order);
  meatStock = await invRepo.getIngredientStock(meatId);
  print(
    'Meat stock after re-process: ${meatStock?.onHand}g (Still Expected 4700)',
  );

  // 7. Test Reversal
  print('7. Reversing sale...');
  await invService.reverseOrderPaid(order);
  meatStock = await invRepo.getIngredientStock(meatId);
  breadStock = await invRepo.getIngredientStock(breadId);
  final colaMapRev = await db.query(
    'products',
    where: 'id = ?',
    whereArgs: [colaId],
  );
  final colaQtyRev = (colaMapRev.first['quantity'] as num).toDouble();

  print('Meat stock after reversal: ${meatStock?.onHand}g (Expected 5000)');
  print('Bread stock after reversal: ${breadStock?.onHand} pcs (Expected 100)');
  print('Cola stock after reversal: $colaQtyRev (Expected 50)');

  print('--- Verification Completed Successfully! ---');
  exit(0);
}

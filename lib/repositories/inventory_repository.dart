import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database_helper.dart';
import '../models/inventory_models.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Ingredients ---

  Future<int> insertIngredient(Ingredient ingredient) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final id = await txn.insert('ingredients', ingredient.toMap());
      // Initialize stock entry
      await txn.insert('ingredient_stock', {
        'ingredient_id': id,
        'on_hand': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return id;
    });
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('ingredients');
    return List.generate(maps.length, (i) => Ingredient.fromMap(maps[i]));
  }

  Future<int> updateIngredient(Ingredient ingredient) async {
    final db = await _dbHelper.database;
    return await db.update(
      'ingredients',
      ingredient.toMap(),
      where: 'id = ?',
      whereArgs: [ingredient.id],
    );
  }

  Future<int> deleteIngredient(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
  }

  Future<IngredientStock?> getIngredientStock(int ingredientId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ingredient_stock',
      where: 'ingredient_id = ?',
      whereArgs: [ingredientId],
    );
    if (maps.isEmpty) return null;
    return IngredientStock.fromMap(maps.first);
  }

  // --- Recipes ---

  Future<int> upsertRecipe(Recipe recipe) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Delete existing recipe and items (Cascade handles items usually, but let's be explicit if needed)
      await txn.delete(
        'recipes',
        where: 'product_id = ?',
        whereArgs: [recipe.productId],
      );

      // 2. Insert new recipe
      final recipeId = await txn.insert('recipes', recipe.toMap());

      // 3. Insert items
      for (var item in recipe.items) {
        await txn.insert(
          'recipe_items',
          item.copyWith(recipeId: recipeId).toMap(),
        );
      }
      return recipeId;
    });
  }

  Future<Recipe?> getRecipeForProduct(int productId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> recipeMaps = await db.query(
      'recipes',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    if (recipeMaps.isEmpty) return null;

    final recipeMap = recipeMaps.first;
    final recipeId = recipeMap['id'];

    final List<Map<String, dynamic>> itemMaps = await db.rawQuery(
      '''
      SELECT ri.*, i.name as ingredient_name 
      FROM recipe_items ri
      JOIN ingredients i ON ri.ingredient_id = i.id
      WHERE ri.recipe_id = ?
    ''',
      [recipeId],
    );

    final items = itemMaps
        .map((m) => RecipeItem.fromMap(m, ingredientName: m['ingredient_name']))
        .toList();
    return Recipe.fromMap(recipeMap, items: items);
  }

  // --- Transactions / Stock Movements ---

  Future<void> addStockMovement(
    StockMovement movement,
    Transaction? txn,
  ) async {
    final executor = txn ?? (await _dbHelper.database);

    // 1. Insert Movement
    await executor.insert('stock_movements', movement.toMap());

    // 2. Update Stock
    double factor = 1.0;
    if (movement.type == MovementType.OUT) factor = -1.0;
    if (movement.type == MovementType.RETURN) factor = 1.0;
    if (movement.type == MovementType.IN) factor = 1.0;

    if (movement.type == MovementType.ADJUST) {
      await executor.update(
        'ingredient_stock',
        {
          'on_hand': movement.qty,
          'updated_at': movement.createdAt.toIso8601String(),
        },
        where: 'ingredient_id = ?',
        whereArgs: [movement.ingredientId],
      );
    } else {
      await executor.rawUpdate(
        '''
        UPDATE ingredient_stock 
        SET on_hand = on_hand + ?, updated_at = ?
        WHERE ingredient_id = ?
      ''',
        [
          movement.qty * factor,
          movement.createdAt.toIso8601String(),
          movement.ingredientId,
        ],
      );
    }
  }

  // --- Flags ---

  Future<OrderInventoryFlag?> getInventoryFlag(String orderId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'order_inventory_flags',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    if (maps.isEmpty) return null;
    return OrderInventoryFlag.fromMap(maps.first);
  }

  Future<void> setInventoryFlag(
    OrderInventoryFlag flag,
    Transaction? txn,
  ) async {
    final executor = txn ?? (await _dbHelper.database);
    await executor.insert(
      'order_inventory_flags',
      flag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getStockMovements() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT sm.*, i.name as ingredient_name, i.base_unit
      FROM stock_movements sm
      JOIN ingredients i ON sm.ingredient_id = i.id
      ORDER BY sm.created_at DESC
      LIMIT 100
    ''');
  }
}

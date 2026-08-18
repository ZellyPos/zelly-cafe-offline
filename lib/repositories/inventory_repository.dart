import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database_helper.dart';
import '../core/errors/insufficient_stock.dart';
import '../models/inventory_models.dart';

/// Ombor birligi turi: xomashyo yoki tayyor mahsulot.
enum StockItemKind { ingredient, product }

/// Harakat yo'nalishi: kirim yoki chiqim.
enum StockDirection { inbound, outbound }

/// Kirim/Chiqim sahifasidagi bitta qator (§4.5).
class StockBatchLine {
  final StockItemKind kind;
  final int itemId;
  final StockDirection direction;
  final double qty;

  /// Tannarx — faqat kirimda ishlatiladi (o'rtacha tannarx hisobi uchun).
  final double cost;

  /// "Kimdan olindi" — faqat kirimda.
  final String? supplier;

  /// Izoh — asosan chiqimda (sabab).
  final String? note;

  const StockBatchLine({
    required this.kind,
    required this.itemId,
    required this.direction,
    required this.qty,
    this.cost = 0,
    this.supplier,
    this.note,
  });
}

/// Harakat jurnaliga yoziladigan qatorga nom/birlik **snapshot**'ini qo'shadi
/// (§20).
///
/// `stock_movements` / `product_movements` — moliyaviy ledger: xomashyo yoki
/// mahsulot keyin o'chirilsa, `JOIN` orqali nom topilmaydi. Shuning uchun nom
/// va birlik yozuv kiritilayotgan paytda ko'chirib olinadi.
///
/// Trigger ishlatilmaydi: SQLite `ALTER TABLE ... RENAME` paytida trigger
/// tanasini tekshiradi, shu sabab jadval qayta qurilishi (migratsiyalarda tez
/// uchraydi) uzilib qolardi.
Future<Map<String, Object?>> withItemSnapshot(
  DatabaseExecutor executor,
  Map<String, Object?> row, {
  required StockItemKind kind,
}) async {
  final isIngredient = kind == StockItemKind.ingredient;
  final id = row[isIngredient ? 'ingredient_id' : 'product_id'];
  if (id == null) return row;

  final rows = await executor.query(
    isIngredient ? 'ingredients' : 'products',
    columns: ['name', if (isIngredient) 'base_unit' else 'unit'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (rows.isEmpty) return row;

  return {
    ...row,
    'item_name': rows.first['name'],
    'item_unit': rows.first[isIngredient ? 'base_unit' : 'unit'],
  };
}

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

  /// Faol xomashyolar. O'chirilganlari (`is_active = 0`) qaytmaydi — ular
  /// faqat harakatlar tarixida ko'rinadi.
  Future<List<Ingredient>> getAllIngredients() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ingredients',
      where: 'is_active = 1',
    );
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

  /// Xomashyoni **yumshoq** o'chiradi (`is_active = 0`).
  ///
  /// Fizik `DELETE` qilinmaydi: `stock_movements` dagi harakatlar tarixi
  /// moliyaviy jurnal — xomashyo o'chirilgani sababli yo'qolmasligi kerak
  /// (§20). Qator faqat retention muddati (§19) o'tganda tozalanadi.
  Future<int> deleteIngredient(int id) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // Retseptlar — joriy sozlama, tarix emas: o'chirilgan xomashyo faol
      // retseptda qolmasligi kerak (aks holda ro'yxatda "?" bo'lib turadi).
      await txn.delete(
        'recipe_items',
        where: 'ingredient_id = ?',
        whereArgs: [id],
      );
      return txn.update(
        'ingredients',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
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
    await executor.insert(
      'stock_movements',
      await withItemSnapshot(
        executor,
        movement.toMap(),
        kind: StockItemKind.ingredient,
      ),
    );

    // 2. Update Stock
    double factor = 1.0;
    if (movement.type == MovementType.stockOut) factor = -1.0;
    if (movement.type == MovementType.stockReturn) factor = 1.0;
    if (movement.type == MovementType.stockIn) factor = 1.0;

    if (movement.type == MovementType.adjust) {
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

  Future<OrderInventoryFlag?> getInventoryFlag(
    String orderId, [
    Transaction? txn,
  ]) async {
    final executor = txn ?? (await _dbHelper.database);
    final List<Map<String, dynamic>> maps = await executor.query(
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

  // --- Kirim / Chiqim (tannarx + yetkazuvchi) ---

  /// Xomashyo kirimi: qoldiq ↑ va o'rtacha tannarx qayta hisoblanadi
  /// (og'irlikli o'rtacha).
  Future<void> stockIn({
    required int ingredientId,
    required double qty,
    double cost = 0,
    String? supplier,
    int? userId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction(
      (txn) => _ingredientIn(
        txn,
        DateTime.now().toIso8601String(),
        ingredientId: ingredientId,
        qty: qty,
        cost: cost,
        supplier: supplier,
        userId: userId,
      ),
    );
  }

  /// Xomashyo chiqimi (waste yoki boshqa sabab).
  Future<void> stockOut({
    required int ingredientId,
    required double qty,
    String reason = 'waste',
    String? note,
    int? userId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction(
      (txn) => _ingredientOut(
        txn,
        DateTime.now().toIso8601String(),
        ingredientId: ingredientId,
        qty: qty,
        reason: reason,
        note: note,
        userId: userId,
      ),
    );
  }

  /// Resale (sotib olinadigan) mahsulot kirimi: son ↑ va o'rtacha tannarx.
  Future<void> resaleStockIn({
    required int productId,
    required double qty,
    double cost = 0,
    String? supplier,
    int? userId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction(
      (txn) => _productIn(
        txn,
        DateTime.now().toIso8601String(),
        productId: productId,
        qty: qty,
        cost: cost,
        supplier: supplier,
        userId: userId,
      ),
    );
  }

  /// Tayyor mahsulot chiqimi (buzilish / waste).
  Future<void> productWaste({
    required int productId,
    required double qty,
    String? note,
    int? userId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction(
      (txn) => _productOut(
        txn,
        DateTime.now().toIso8601String(),
        productId: productId,
        qty: qty,
        note: note,
        userId: userId,
      ),
    );
  }

  /// Ko'p qatorli kirim/chiqim (§4.5) — **bitta tranzaksiyada**.
  ///
  /// Bitta qator xato bersa hammasi bekor bo'ladi: yarim yozilgan holat
  /// bo'lmaydi.
  Future<void> applyStockBatch(
    List<StockBatchLine> lines, {
    int? userId,
  }) async {
    if (lines.isEmpty) return;
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      // Yozishdan **oldin** butun to'plam tekshiriladi: chiqim qoldiqni
      // manfiyga tushirmasin. Bir birlik bir necha qatorda uchrasa miqdorlar
      // jamlanadi. Yetmasa — barcha yetishmovchiliklar bitta xabarda.
      await _assertOutboundAvailable(txn, lines);
      for (final line in lines) {
        final isIn = line.direction == StockDirection.inbound;
        if (line.kind == StockItemKind.ingredient) {
          if (isIn) {
            await _ingredientIn(
              txn,
              now,
              ingredientId: line.itemId,
              qty: line.qty,
              cost: line.cost,
              supplier: line.supplier,
              userId: userId,
            );
          } else {
            await _ingredientOut(
              txn,
              now,
              ingredientId: line.itemId,
              qty: line.qty,
              note: line.note,
              userId: userId,
            );
          }
        } else {
          if (isIn) {
            await _productIn(
              txn,
              now,
              productId: line.itemId,
              qty: line.qty,
              cost: line.cost,
              supplier: line.supplier,
              userId: userId,
            );
          } else {
            await _productOut(
              txn,
              now,
              productId: line.itemId,
              qty: line.qty,
              note: line.note,
              userId: userId,
            );
          }
        }
      }
    });
  }

  /// To'plamdagi barcha chiqim qatorlarini qoldiqqa solishtiradi.
  ///
  /// Yetmasa [InsufficientStockException] tashlanadi — tranzaksiya rollback
  /// bo'ladi, ya'ni **qisman yozilish yo'q**.
  Future<void> _assertOutboundAvailable(
    Transaction txn,
    List<StockBatchLine> lines,
  ) async {
    final needed = <String, double>{};
    for (final line in lines) {
      if (line.direction != StockDirection.outbound) continue;
      final key = '${line.kind.name}:${line.itemId}';
      needed[key] = (needed[key] ?? 0) + line.qty;
    }
    if (needed.isEmpty) return;

    final shortages =
        <({String name, double need, double onHand, String unit})>[];

    for (final entry in needed.entries) {
      final parts = entry.key.split(':');
      final itemId = int.parse(parts[1]);
      final need = entry.value;

      if (parts[0] == StockItemKind.ingredient.name) {
        final rows = await txn.rawQuery(
          '''
          SELECT i.name, i.base_unit, COALESCE(s.on_hand, 0) AS on_hand
          FROM ingredients i
          LEFT JOIN ingredient_stock s ON s.ingredient_id = i.id
          WHERE i.id = ?
        ''',
          [itemId],
        );
        if (rows.isEmpty) continue;
        final onHand = (rows.first['on_hand'] as num).toDouble();
        if (need > onHand + 1e-9) {
          shortages.add((
            name: rows.first['name'] as String,
            need: need,
            onHand: onHand,
            unit: rows.first['base_unit'] as String? ?? '',
          ));
        }
      } else {
        final rows = await txn.query(
          'products',
          columns: ['name', 'quantity', 'unit'],
          where: 'id = ?',
          whereArgs: [itemId],
        );
        if (rows.isEmpty) continue;
        // `quantity IS NULL` — soni yuritilmaydi, cheklov qo'llanmaydi.
        final rawQty = rows.first['quantity'] as num?;
        if (rawQty == null) continue;
        final onHand = rawQty.toDouble();
        if (need > onHand + 1e-9) {
          shortages.add((
            name: rows.first['name'] as String? ?? 'Mahsulot #$itemId',
            need: need,
            onHand: onHand,
            unit: rows.first['unit'] as String? ?? 'dona',
          ));
        }
      }
    }

    if (shortages.isNotEmpty) throw InsufficientStockException(shortages);
  }

  // --- Kirim/chiqim primitivlari (tranzaksiya ichida ishlaydi) ---

  Future<void> _ingredientIn(
    Transaction txn,
    String now, {
    required int ingredientId,
    required double qty,
    required double cost,
    String? supplier,
    int? userId,
  }) async {
    final stockRows = await txn.query(
      'ingredient_stock',
      where: 'ingredient_id = ?',
      whereArgs: [ingredientId],
    );
    final onHand = stockRows.isNotEmpty
        ? (stockRows.first['on_hand'] as num).toDouble()
        : 0.0;
    final ingRows = await txn.query(
      'ingredients',
      columns: ['avg_cost'],
      where: 'id = ?',
      whereArgs: [ingredientId],
    );
    final oldAvg = ingRows.isNotEmpty
        ? (ingRows.first['avg_cost'] as num?)?.toDouble() ?? 0
        : 0;

    // Og'irlikli o'rtacha tannarx. Tannarx kiritilmagan bo'lsa (cost <= 0)
    // eski o'rtachani nolga tushirib yubormaymiz.
    final newOnHand = onHand + qty;
    final double newAvg;
    if (cost <= 0) {
      newAvg = oldAvg.toDouble();
    } else {
      newAvg = newOnHand > 0
          ? (onHand * oldAvg + qty * cost) / newOnHand
          : cost;
    }

    await txn.insert(
      'stock_movements',
      await withItemSnapshot(txn, {
        'ingredient_id': ingredientId,
        'type': 'IN',
        'qty': qty,
        'reason': 'purchase',
        'cost_price': cost,
        'supplier': supplier,
        'created_at': now,
        'created_by': userId,
      }, kind: StockItemKind.ingredient),
    );
    await txn.rawUpdate(
      'UPDATE ingredient_stock SET on_hand = on_hand + ?, updated_at = ? WHERE ingredient_id = ?',
      [qty, now, ingredientId],
    );
    await txn.update(
      'ingredients',
      {'avg_cost': newAvg},
      where: 'id = ?',
      whereArgs: [ingredientId],
    );
  }

  Future<void> _ingredientOut(
    Transaction txn,
    String now, {
    required int ingredientId,
    required double qty,
    String reason = 'waste',
    String? note,
    int? userId,
    bool allowNegative = false,
  }) async {
    if (!allowNegative) {
      final rows = await txn.rawQuery(
        '''
        SELECT i.name, i.base_unit, COALESCE(s.on_hand, 0) AS on_hand
        FROM ingredients i
        LEFT JOIN ingredient_stock s ON s.ingredient_id = i.id
        WHERE i.id = ?
      ''',
        [ingredientId],
      );
      final onHand = rows.isEmpty
          ? 0.0
          : (rows.first['on_hand'] as num).toDouble();
      // 1e-9 — suzuvchi nuqta xatosi tufayli teng miqdor "yetmadi" bo'lmasin.
      if (qty > onHand + 1e-9) {
        throw InsufficientStockException([
          (
            name: rows.isEmpty
                ? 'Xomashyo #$ingredientId'
                : rows.first['name'] as String,
            need: qty,
            onHand: onHand,
            unit: rows.isEmpty ? '' : (rows.first['base_unit'] as String? ?? ''),
          ),
        ]);
      }
    }

    await txn.insert(
      'stock_movements',
      await withItemSnapshot(txn, {
        'ingredient_id': ingredientId,
        'type': 'OUT',
        'qty': qty,
        'reason': reason,
        'note': note,
        'created_at': now,
        'created_by': userId,
      }, kind: StockItemKind.ingredient),
    );
    await txn.rawUpdate(
      'UPDATE ingredient_stock SET on_hand = on_hand - ?, updated_at = ? WHERE ingredient_id = ?',
      [qty, now, ingredientId],
    );
  }

  Future<void> _productIn(
    Transaction txn,
    String now, {
    required int productId,
    required double qty,
    required double cost,
    String? supplier,
    int? userId,
  }) async {
    final rows = await txn.query(
      'products',
      columns: ['quantity', 'avg_cost'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    final oldQty = rows.isNotEmpty
        ? (rows.first['quantity'] as num?)?.toDouble() ?? 0
        : 0;
    final oldAvg = rows.isNotEmpty
        ? (rows.first['avg_cost'] as num?)?.toDouble() ?? 0
        : 0;
    final newQty = oldQty + qty;
    final double newAvg;
    if (cost <= 0) {
      newAvg = oldAvg.toDouble();
    } else {
      newAvg = newQty > 0 ? (oldQty * oldAvg + qty * cost) / newQty : cost;
    }

    await txn.rawUpdate(
      'UPDATE products SET quantity = COALESCE(quantity, 0) + ?, avg_cost = ? WHERE id = ?',
      [qty, newAvg, productId],
    );
    await txn.insert(
      'product_movements',
      await withItemSnapshot(txn, {
        'product_id': productId,
        'type': 'PURCHASE',
        'qty': qty,
        'cost_price': cost,
        'supplier': supplier,
        'created_at': now,
        'created_by': userId,
      }, kind: StockItemKind.product),
    );
  }

  Future<void> _productOut(
    Transaction txn,
    String now, {
    required int productId,
    required double qty,
    String? note,
    int? userId,
    bool allowNegative = false,
  }) async {
    if (!allowNegative) {
      final rows = await txn.query(
        'products',
        columns: ['name', 'quantity', 'unit'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      // `quantity IS NULL` — soni yuritilmaydigan mahsulot; unga cheklov yo'q.
      final rawQty = rows.isEmpty ? null : rows.first['quantity'] as num?;
      if (rawQty != null) {
        final onHand = rawQty.toDouble();
        if (qty > onHand + 1e-9) {
          throw InsufficientStockException([
            (
              name: rows.first['name'] as String? ?? 'Mahsulot #$productId',
              need: qty,
              onHand: onHand,
              unit: rows.first['unit'] as String? ?? 'dona',
            ),
          ]);
        }
      }
    }

    await txn.rawUpdate(
      'UPDATE products SET quantity = COALESCE(quantity, 0) - ? WHERE id = ?',
      [qty, productId],
    );
    await txn.insert(
      'product_movements',
      await withItemSnapshot(txn, {
        'product_id': productId,
        'type': 'WASTE',
        'qty': qty,
        'note': note,
        'created_at': now,
        'created_by': userId,
      }, kind: StockItemKind.product),
    );
  }

  // --- Inventarizatsiya (real songa tenglashtirish) ---

  /// Xomashyolarni real songa tenglashtiradi; farqni ADJUST sifatida yozadi.
  Future<void> reconcileIngredients(
    Map<int, double> realCounts, {
    int? userId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final entry in realCounts.entries) {
        final rows = await txn.query(
          'ingredient_stock',
          where: 'ingredient_id = ?',
          whereArgs: [entry.key],
        );
        final system = rows.isNotEmpty
            ? (rows.first['on_hand'] as num).toDouble()
            : 0.0;
        final diff = entry.value - system;
        await txn.update(
          'ingredient_stock',
          {'on_hand': entry.value, 'updated_at': now},
          where: 'ingredient_id = ?',
          whereArgs: [entry.key],
        );
        await txn.insert(
          'stock_movements',
          await withItemSnapshot(txn, {
            'ingredient_id': entry.key,
            'type': 'ADJUST',
            'qty': diff,
            'reason': 'inventory',
            'created_at': now,
            'created_by': userId,
          }, kind: StockItemKind.ingredient),
        );
      }
    });
  }

  /// Tayyor mahsulotlarni real songa tenglashtiradi; farqni ADJUST sifatida yozadi.
  Future<void> reconcileProducts(
    Map<int, double> realCounts, {
    int? userId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final entry in realCounts.entries) {
        final rows = await txn.query(
          'products',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        final system = rows.isNotEmpty
            ? (rows.first['quantity'] as num?)?.toDouble() ?? 0
            : 0;
        final diff = entry.value - system;
        await txn.rawUpdate('UPDATE products SET quantity = ? WHERE id = ?', [
          entry.value,
          entry.key,
        ]);
        await txn.insert(
          'product_movements',
          await withItemSnapshot(txn, {
            'product_id': entry.key,
            'type': 'ADJUST',
            'qty': diff,
            'note': 'inventory',
            'created_at': now,
            'created_by': userId,
          }, kind: StockItemKind.product),
        );
      }
    });
  }

  // --- O'qish (ombor ekranlari uchun) ---

  /// Xomashyolar qoldiq bilan birga (JOIN).
  Future<List<Map<String, dynamic>>> getIngredientsWithStock() async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT i.*, COALESCE(s.on_hand, 0) as on_hand
      FROM ingredients i
      LEFT JOIN ingredient_stock s ON s.ingredient_id = i.id
      WHERE i.is_active = 1
      ORDER BY i.name ASC
    ''');
  }

  /// Tayyor (prepared) mahsulotlar.
  Future<List<Map<String, dynamic>>> getPreparedProducts() async {
    final db = await _dbHelper.database;
    return db.query(
      'products',
      where: "product_type = 'prepared' AND is_active = 1",
      orderBy: 'sort_order ASC',
    );
  }

  /// Resale (sotib olinadigan) mahsulotlar.
  Future<List<Map<String, dynamic>>> getResaleProducts() async {
    final db = await _dbHelper.database;
    return db.query(
      'products',
      where: "product_type = 'resale' AND is_active = 1",
      orderBy: 'sort_order ASC',
    );
  }

  /// Pishirishda xomashyo chegirilganda `stock_movements.reason` shu qiymat
  /// bilan yoziladi. Tarixda bunday qator oddiy chiqim emas — **sarf**
  /// (`CONSUME`) sifatida ko'rsatiladi (§18).
  static const productionReason = 'production';

  /// Tarixdagi sarf (pishirishga ketgan xomashyo) turining sun'iy kodi.
  /// DB'da alohida `type` yo'q — `OUT` + `reason='production'` shunga aylanadi.
  static const consumeType = 'CONSUME';

  /// [getHistory] va [getHistoryCount] uchun umumiy WHERE/JOIN qismlari.
  ///
  /// Ikkala so'rov bir xil filtrlarni ishlatadi — mantiq bitta joyda tursin
  /// (aks holda filtr qo'shilganda sanoq bilan ro'yxat bir-biriga mos
  /// kelmay qolardi).
  ///
  /// Qaytadi: `(ingredientWhere, productWhere)`; [args] to'ldiriladi —
  /// **chaqiruv tartibi muhim**: avval xomashyo, keyin mahsulot qismi.
  ({String? ingredient, String? product}) _historyFilters({
    required List<Object?> args,
    DateTime? from,
    DateTime? to,
    List<String>? types,
    int? itemId,
    String? source,
    String? search,
  }) {
    String dateFilter(String alias) {
      var sql = '';
      if (from != null) {
        sql += ' AND $alias.created_at >= ?';
        args.add(from.toIso8601String());
      }
      if (to != null) {
        sql += ' AND $alias.created_at <= ?';
        args.add(to.toIso8601String());
      }
      return sql;
    }

    // `CONSUME` — DB'da yo'q, u `OUT` + `reason='production'`. Shu sababli
    // oddiy `OUT` filtri sarf qatorlarini **chiqarib tashlaydi**, aks holda
    // ikkala chip bir xil natija berardi.
    String typeFilter(String alias, {required bool ingredient}) {
      if (types == null || types.isEmpty) return '';
      final ors = <String>[];
      final plain = <String>[];
      for (final t in types) {
        if (ingredient && t == consumeType) {
          ors.add("($alias.type = 'OUT' AND $alias.reason = ?)");
          args.add(productionReason);
        } else if (ingredient && t == 'OUT') {
          ors.add(
            "($alias.type = 'OUT' AND ($alias.reason IS NULL OR $alias.reason <> ?))",
          );
          args.add(productionReason);
        } else if (!ingredient && t == consumeType) {
          continue; // Mahsulot jurnalida sarf yo'q
        } else {
          plain.add(t);
        }
      }
      if (plain.isNotEmpty) {
        ors.add('$alias.type IN (${List.filled(plain.length, '?').join(',')})');
        args.addAll(plain);
      }
      if (ors.isEmpty) return ' AND 1=0'; // Faqat mos kelmaydigan tur tanlangan
      return ' AND (${ors.join(' OR ')})';
    }

    /// Qidiruv (§17): nomi, izohi, yetkazuvchi va sarfda — qaysi mahsulot
    /// uchun ketgani.
    String searchFilter(List<String> columns) {
      final q = search?.trim();
      if (q == null || q.isEmpty) return '';
      final like = '%$q%';
      for (var i = 0; i < columns.length; i++) {
        args.add(like);
      }
      return ' AND (${columns.map((c) => '$c LIKE ?').join(' OR ')})';
    }

    String? ingredientWhere;
    String? productWhere;

    if (source == null || source == 'ingredient') {
      var w = '1=1';
      if (itemId != null) {
        w += ' AND sm.ingredient_id = ?';
        args.add(itemId);
      }
      w += dateFilter('sm');
      w += typeFilter('sm', ingredient: true);
      // `i.name` emas — o'chirilgan xomashyoda u NULL, `LIKE` hech qachon mos
      // kelmasdi. Ekranda ko'rinayotgan nom bo'yicha qidiriladi.
      w += searchFilter([
        _historyName('i', 'sm', 'ingredient_id'),
        'sm.note',
        'sm.supplier',
        'rp.name',
      ]);
      ingredientWhere = w;
    }

    if (source == null || source == 'product') {
      var w = '1=1';
      if (itemId != null) {
        w += ' AND pm.product_id = ?';
        args.add(itemId);
      }
      w += dateFilter('pm');
      w += typeFilter('pm', ingredient: false);
      w += searchFilter([
        _historyName('p', 'pm', 'product_id'),
        'pm.note',
        'pm.supplier',
      ]);
      productWhere = w;
    }

    return (ingredient: ingredientWhere, product: productWhere);
  }

  /// Sarf qatorlarida "qaysi mahsulot pishirilganda" — `ref_id` matn sifatida
  /// saqlanadi, shuning uchun `CAST` bilan bog'lanadi.
  static const _refProductJoin =
      "LEFT JOIN products rp ON sm.ref_table = 'products' "
      'AND sm.ref_id = CAST(rp.id AS TEXT)';

  /// Tarixdagi nom (§20), muhimlik tartibida:
  /// 1. joriy nom — element bor bo'lsa (nomi tuzatilgan bo'lsa yangisi
  ///    hamma joyda bir xil ko'rinsin);
  /// 2. `item_name` snapshot — yozuv kiritilgan paytdagi nom, element
  ///    o'chirilgan bo'lsa;
  /// 3. `O'chirilgan #id` — snapshot'gacha yozilgan eski qatorlar uchun.
  static String _historyName(String item, String mv, String fk) =>
      "COALESCE($item.name, $mv.item_name, 'O''chirilgan #' || $mv.$fk)";

  /// Birlik uchun ham xuddi shunday zanjir — o'chirilgan xomashyoning miqdori
  /// birliksiz o'qilmaydi ("300" — gramm mi, dona mi?).
  static String _historyUnit(String item, String mv, String col, String or) =>
      "COALESCE($item.$col, $mv.item_unit, '$or')";

  /// Birlashgan harakatlar tarixi: xomashyo (`stock_movements`) + tayyor
  /// mahsulot (`product_movements`) — §4.6 ekrani uchun.
  ///
  /// Qaytadi: `source` ('ingredient'|'product'), `item_id`, `item_name`,
  /// `unit`, `type`, `qty`, `cost_price`, `supplier`, `note`, `reason`,
  /// `ref_name`, `created_at`, `created_by`, `user_name`.
  ///
  /// [types] — `IN/OUT/CONSUME/ADJUST/RETURN/PRODUCE/PURCHASE/SALE/WASTE`.
  /// [source] — `'ingredient'` yoki `'product'`; `null` bo'lsa ikkalasi.
  /// [search] — nom / izoh / yetkazuvchi / pishirilgan mahsulot bo'yicha.
  Future<List<Map<String, dynamic>>> getHistory({
    DateTime? from,
    DateTime? to,
    List<String>? types,
    int? itemId,
    String? source,
    String? search,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _dbHelper.database;
    final args = <Object?>[];
    final where = _historyFilters(
      args: args,
      from: from,
      to: to,
      types: types,
      itemId: itemId,
      source: source,
      search: search,
    );

    final parts = <String>[];

    if (where.ingredient != null) {
      parts.add('''
        SELECT 'ingredient' AS source, sm.id AS id, sm.ingredient_id AS item_id,
               ${_historyName('i', 'sm', 'ingredient_id')} AS item_name,
               ${_historyUnit('i', 'sm', 'base_unit', '')} AS unit,
               CASE WHEN sm.type = 'OUT' AND sm.reason = '$productionReason'
                    THEN '$consumeType' ELSE sm.type END AS type,
               sm.qty AS qty, sm.cost_price AS cost_price,
               sm.supplier AS supplier, sm.note AS note, sm.reason AS reason,
               rp.name AS ref_name,
               sm.created_at AS created_at, sm.created_by AS created_by,
               u.name AS user_name
        FROM stock_movements sm
        LEFT JOIN ingredients i ON sm.ingredient_id = i.id
        LEFT JOIN users u ON sm.created_by = u.id
        $_refProductJoin
        WHERE ${where.ingredient}
      ''');
    }

    if (where.product != null) {
      parts.add('''
        SELECT 'product' AS source, pm.id AS id, pm.product_id AS item_id,
               ${_historyName('p', 'pm', 'product_id')} AS item_name,
               ${_historyUnit('p', 'pm', 'unit', 'dona')} AS unit,
               pm.type AS type, pm.qty AS qty, pm.cost_price AS cost_price,
               pm.supplier AS supplier, pm.note AS note, NULL AS reason,
               NULL AS ref_name,
               pm.created_at AS created_at, pm.created_by AS created_by,
               u.name AS user_name
        FROM product_movements pm
        LEFT JOIN products p ON pm.product_id = p.id
        LEFT JOIN users u ON pm.created_by = u.id
        WHERE ${where.product}
      ''');
    }

    if (parts.isEmpty) return [];
    args.add(limit);
    args.add(offset);
    return db.rawQuery(
      '${parts.join(' UNION ALL ')} ORDER BY created_at DESC LIMIT ? OFFSET ?',
      args,
    );
  }

  /// [getHistory] bilan bir xil filtrlardagi yozuvlar **soni** — sahifalash
  /// uchun ("1–50 / 1240").
  Future<int> getHistoryCount({
    DateTime? from,
    DateTime? to,
    List<String>? types,
    int? itemId,
    String? source,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final args = <Object?>[];
    final where = _historyFilters(
      args: args,
      from: from,
      to: to,
      types: types,
      itemId: itemId,
      source: source,
      search: search,
    );

    final parts = <String>[];

    if (where.ingredient != null) {
      parts.add('''
        SELECT COUNT(*) AS cnt FROM stock_movements sm
        LEFT JOIN ingredients i ON sm.ingredient_id = i.id
        $_refProductJoin
        WHERE ${where.ingredient}
      ''');
    }

    if (where.product != null) {
      parts.add('''
        SELECT COUNT(*) AS cnt FROM product_movements pm
        LEFT JOIN products p ON pm.product_id = p.id
        WHERE ${where.product}
      ''');
    }

    if (parts.isEmpty) return 0;
    final rows = await db.rawQuery(
      'SELECT SUM(cnt) AS total FROM (${parts.join(' UNION ALL ')})',
      args,
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Harakatlar tarixini muddati o'tgan yozuvlardan tozalaydi (§19).
  ///
  /// Yozuv **faqat yoshi bo'yicha** o'chadi — xomashyo/mahsulot o'chirilgani
  /// sababli emas (§20). Shuning uchun yumshoq o'chirilgan xomashyo qatori
  /// ham faqat unga tegishli oxirgi harakat ketgandan keyin yo'q qilinadi,
  /// aks holda undan oldingi tarix nomsiz qolardi.
  ///
  /// [months] `<= 0` bo'lsa hech nima o'chirilmaydi ("cheksiz saqlash").
  /// Qaytadi: o'chirilgan qatorlar soni.
  Future<({int ingredient, int product})> purgeHistoryOlderThan(
    int months, {
    DateTime? now,
  }) async {
    if (months <= 0) return (ingredient: 0, product: 0);

    final ref = now ?? DateTime.now();
    final cutoff = DateTime(
      ref.year,
      ref.month - months,
      ref.day,
      ref.hour,
      ref.minute,
      ref.second,
    ).toIso8601String();

    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final ing = await txn.delete(
        'stock_movements',
        where: 'created_at < ?',
        whereArgs: [cutoff],
      );
      final prod = await txn.delete(
        'product_movements',
        where: 'created_at < ?',
        whereArgs: [cutoff],
      );

      // Endi hech qanday tarixi qolmagan, o'chirilgan xomashyolarni fizik
      // yo'q qilamiz — bazada abadiy o'sib boradigan "o'lik" qatorlar
      // qolmasin.
      await txn.rawDelete('''
        DELETE FROM ingredient_stock WHERE ingredient_id IN (
          SELECT id FROM ingredients WHERE is_active = 0
            AND id NOT IN (SELECT DISTINCT ingredient_id FROM stock_movements
                           WHERE ingredient_id IS NOT NULL)
        )
      ''');
      await txn.rawDelete('''
        DELETE FROM ingredients WHERE is_active = 0
          AND id NOT IN (SELECT DISTINCT ingredient_id FROM stock_movements
                         WHERE ingredient_id IS NOT NULL)
      ''');

      return (ingredient: ing, product: prod);
    });
  }

  /// Bo'shagan sahifalarni operatsion tizimga qaytaradi.
  ///
  /// `DELETE` o'zi fayl hajmini kichraytirmaydi — `VACUUM` bo'lmasa
  /// tozalashning ma'nosi qolmaydi. Tranzaksiya ichida ishlamaydi, shuning
  /// uchun [purgeHistoryOlderThan] dan **keyin** alohida chaqiriladi.
  Future<void> vacuum() async {
    final db = await _dbHelper.database;
    await db.execute('VACUUM');
  }

  /// Mahsulot turini o'zgartiradi: `'prepared'` (tayyorlanadi, retseptli) yoki
  /// `'resale'` (sotib olinadi, kirim qilinadi).
  ///
  /// `resale` ga o'tkazilganda retsept **o'chiriladi** — sotib olinadigan
  /// mahsulotda retsept ma'nosiz va pishirish ro'yxatiga tushib qolardi.
  Future<void> setProductType(int productId, String type) async {
    assert(type == 'prepared' || type == 'resale');
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'product_type': type},
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (type == 'resale') {
        await txn.delete(
          'recipes',
          where: 'product_id = ?',
          whereArgs: [productId],
        );
      }
    });
  }

  // --- Food-cost (§3) ---

  /// Bitta mahsulotning retsept tannarxi:
  /// `Σ(item.qty × ingredient.avg_cost) / yield_qty`.
  ///
  /// Retsepti yo'q bo'lsa `null` qaytadi (hisoblab bo'lmaydi).
  Future<double?> recipeCost(int productId) async {
    final costs = await getRecipeCosts(productIds: [productId]);
    return costs[productId];
  }

  /// Barcha (yoki berilgan) mahsulotlarning retsept tannarxi — **bitta
  /// so'rovda**, ro'yxat ekranlari uchun (N+1 so'rovning oldini oladi).
  ///
  /// Xomashyoning `avg_cost` i kiritilmagan bo'lsa 0 deb olinadi, ya'ni
  /// natija to'liq bo'lmasligi mumkin — buni UI "taxminiy" deb ko'rsatadi.
  Future<Map<int, double>> getRecipeCosts({List<int>? productIds}) async {
    final db = await _dbHelper.database;
    final args = <Object?>[];
    var where = '';
    if (productIds != null) {
      if (productIds.isEmpty) return {};
      where =
          'WHERE r.product_id IN (${List.filled(productIds.length, '?').join(',')})';
      args.addAll(productIds);
    }

    final rows = await db.rawQuery('''
      SELECT r.product_id AS product_id,
             r.yield_qty AS yield_qty,
             SUM(ri.qty * COALESCE(i.avg_cost, 0)) AS total_cost
      FROM recipes r
      JOIN recipe_items ri ON ri.recipe_id = r.id
      JOIN ingredients i ON i.id = ri.ingredient_id
      $where
      GROUP BY r.id
    ''', args);

    final result = <int, double>{};
    for (final row in rows) {
      final productId = (row['product_id'] as num?)?.toInt();
      if (productId == null) continue;
      final total = (row['total_cost'] as num?)?.toDouble() ?? 0;
      final yieldQty = (row['yield_qty'] as num?)?.toDouble() ?? 1;
      result[productId] = yieldQty > 0 ? total / yieldQty : total;
    }
    return result;
  }

  /// Tayyor mahsulot harakatlari tarixi (pishirish/sotuv/waste/adjust).
  Future<List<Map<String, dynamic>>> getProductMovements({
    int? productId,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    final where = productId != null ? 'WHERE pm.product_id = ?' : '';
    return db.rawQuery('''
      SELECT pm.*, p.name as product_name
      FROM product_movements pm
      JOIN products p ON pm.product_id = p.id
      $where
      ORDER BY pm.created_at DESC
      LIMIT $limit
    ''', productId != null ? [productId] : []);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tezzro/core/database_helper.dart';
import 'package:tezzro/core/services/inventory_service.dart';
import 'package:tezzro/models/inventory_models.dart';
import 'package:tezzro/models/order.dart';
import 'package:tezzro/repositories/inventory_repository.dart';

/// Ombor moduli testlari — **yangi model** (2026-08, `docs/ombor_final.md`):
/// xomashyo faqat **pishirishda** chegiriladi, sotuvda esa faqat tayyor
/// mahsulot soni kamayadi.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final invRepo = InventoryRepository();
  final invService = InventoryService.instance;
  final dbHelper = DatabaseHelper.instance;

  /// Har test uchun toza in-memory baza.
  setUp(() async {
    await dbHelper.close();
    DatabaseHelper.databasePathOverride = inMemoryDatabasePath;
  });

  Future<double> ingredientStock(int id) async =>
      (await invRepo.getIngredientStock(id))?.onHand ?? 0;

  Future<double> productQty(int id) async {
    final db = await dbHelper.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return (rows.first['quantity'] as num?)?.toDouble() ?? 0;
  }

  Future<double> productAvgCost(int id) async {
    final db = await dbHelper.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return (rows.first['avg_cost'] as num?)?.toDouble() ?? 0;
  }

  Future<double> ingredientAvgCost(int id) async {
    final db = await dbHelper.database;
    final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [id]);
    return (rows.first['avg_cost'] as num?)?.toDouble() ?? 0;
  }

  /// Burger (prepared, retseptli) + Cola (resale) muhitini tayyorlaydi.
  Future<({int meatId, int breadId, int burgerId, int colaId})> setupWorld({
    double meatQty = 5000,
    double breadQty = 100,
  }) async {
    final meatId = await invRepo.insertIngredient(
      Ingredient(name: 'Go\'sht', baseUnit: 'g', minStock: 1000),
    );
    final breadId = await invRepo.insertIngredient(
      Ingredient(name: 'Non', baseUnit: 'pcs', minStock: 10),
    );

    final burgerId = await dbHelper.insert('products', {
      'name': 'Burger',
      'price': 25000,
      'category': 'Food',
      'product_type': 'prepared',
      'quantity': 0.0,
      'is_active': 1,
    });
    final colaId = await dbHelper.insert('products', {
      'name': 'Cola 0.5',
      'price': 7000,
      'category': 'Drinks',
      'product_type': 'resale',
      'quantity': 50.0,
      'is_active': 1,
    });

    // 1 burger = 150 g go'sht + 1 non
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

    if (meatQty > 0) {
      await invRepo.stockIn(ingredientId: meatId, qty: meatQty, cost: 80);
    }
    if (breadQty > 0) {
      await invRepo.stockIn(ingredientId: breadId, qty: breadQty, cost: 2000);
    }

    return (
      meatId: meatId,
      breadId: breadId,
      burgerId: burgerId,
      colaId: colaId,
    );
  }

  group('Pishirish (produce)', () {
    test('retsept bo\'yicha xomashyo chegiradi va tayyor sonni oshiradi', () async {
      final w = await setupWorld();

      await invService.produce([(productId: w.burgerId, count: 10)]);

      expect(await ingredientStock(w.meatId), 5000 - 1500); // 10 × 150 g
      expect(await ingredientStock(w.breadId), 100 - 10);
      expect(await productQty(w.burgerId), 10);

      // Harakatlar jurnaliga yozilganmi
      final db = await dbHelper.database;
      final produceRows = await db.query(
        'product_movements',
        where: 'type = ? AND product_id = ?',
        whereArgs: ['PRODUCE', w.burgerId],
      );
      expect(produceRows.length, 1);
      expect((produceRows.first['qty'] as num).toDouble(), 10);

      final outRows = await db.query(
        'stock_movements',
        where: 'reason = ?',
        whereArgs: ['production'],
      );
      expect(outRows.length, 2); // go'sht + non
    });

    test('yield_qty hisobga olinadi (1 retseptdan 4 dona chiqsa)', () async {
      final w = await setupWorld();
      // Retseptni "1 marta pishirsa 4 dona chiqadi" qilib o'zgartiramiz.
      await invRepo.upsertRecipe(
        Recipe(
          productId: w.burgerId,
          yieldQty: 4.0,
          items: [
            RecipeItem(recipeId: 0, ingredientId: w.meatId, qty: 600),
            RecipeItem(recipeId: 0, ingredientId: w.breadId, qty: 4),
          ],
        ),
      );

      await invService.produce([(productId: w.burgerId, count: 8)]);

      // 600/4 × 8 = 1200 g
      expect(await ingredientStock(w.meatId), 5000 - 1200);
      expect(await ingredientStock(w.breadId), 100 - 8);
      expect(await productQty(w.burgerId), 8);
    });

    test('xomashyo yetmasa xato beradi va HECH NARSA o\'zgarmaydi', () async {
      final w = await setupWorld(meatQty: 200, breadQty: 100);

      // 10 burger uchun 1500 g kerak, bor-yo'g'i 200 g bor.
      await expectLater(
        invService.produce([(productId: w.burgerId, count: 10)]),
        throwsA(isA<InsufficientStockException>()),
      );

      // Rollback: qoldiqlar va tayyor son tegilmagan
      expect(await ingredientStock(w.meatId), 200);
      expect(await ingredientStock(w.breadId), 100);
      expect(await productQty(w.burgerId), 0);

      final db = await dbHelper.database;
      expect((await db.query('product_movements')).length, 0);
    });

    test('yetishmovchilik ro\'yxatida nom, kerak va mavjud bo\'ladi', () async {
      final w = await setupWorld(meatQty: 200, breadQty: 3);

      try {
        await invService.produce([(productId: w.burgerId, count: 10)]);
        fail('InsufficientStockException kutilgan edi');
      } on InsufficientStockException catch (e) {
        expect(e.shortages.length, 2); // go'sht ham, non ham yetmaydi
        final meat = e.shortages.firstWhere((s) => s.name == 'Go\'sht');
        expect(meat.need, 1500);
        expect(meat.onHand, 200);
        expect(meat.unit, 'g');
        expect(e.message, contains('Go\'sht'));
      }
    });

    test('bir xomashyo ikki mahsulotda bo\'lsa ehtiyoj JAMLANADI', () async {
      final w = await setupWorld(meatQty: 1000, breadQty: 100);

      // Ikkinchi prepared mahsulot — xuddi shu go'shtdan.
      final kebabId = await dbHelper.insert('products', {
        'name': 'Kabob',
        'price': 30000,
        'category': 'Food',
        'product_type': 'prepared',
        'quantity': 0.0,
        'is_active': 1,
      });
      await invRepo.upsertRecipe(
        Recipe(
          productId: kebabId,
          yieldQty: 1.0,
          items: [RecipeItem(recipeId: 0, ingredientId: w.meatId, qty: 200)],
        ),
      );

      // Burger 4 ta = 600 g, kabob 3 ta = 600 g → jami 1200 g > 1000 g.
      // Alohida-alohida tekshirilsa ikkalasi ham "yetadi" ko'rinardi.
      await expectLater(
        invService.produce([
          (productId: w.burgerId, count: 4),
          (productId: kebabId, count: 3),
        ]),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await ingredientStock(w.meatId), 1000);
    });

    test('allowNegative: true bilan tekshiruv chetlab o\'tiladi', () async {
      final w = await setupWorld(meatQty: 100, breadQty: 100);

      await invService.produce([
        (productId: w.burgerId, count: 2),
      ], allowNegative: true);

      expect(await ingredientStock(w.meatId), 100 - 300); // manfiy
      expect(await productQty(w.burgerId), 2);
    });
  });

  group('Sotuv va qaytarish', () {
    test('sotuv faqat tayyor sonni kamaytiradi, xomashyoga TEGMAYDI', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      final meatAfterProduce = await ingredientStock(w.meatId);
      final breadAfterProduce = await ingredientStock(w.breadId);

      final order = Order(
        id: 'ORDER-1',
        total: 57000,
        paymentType: 'Cash',
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            orderId: 'ORDER-1',
            productId: w.burgerId,
            qty: 2,
            price: 25000,
          ),
          OrderItem(
            orderId: 'ORDER-1',
            productId: w.colaId,
            qty: 1,
            price: 7000,
          ),
        ],
      );
      await invService.processOrderPaid(order);

      // ⭐ Asosiy tekshiruv: xomashyo o'zgarmagan (ikki marta chegirish yo'q)
      expect(await ingredientStock(w.meatId), meatAfterProduce);
      expect(await ingredientStock(w.breadId), breadAfterProduce);

      // Tayyor sonlar kamaygan
      expect(await productQty(w.burgerId), 8); // 10 - 2
      expect(await productQty(w.colaId), 49); // 50 - 1
    });

    test('bir buyurtma ikki marta hisoblanmaydi (idempotent)', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      final order = Order(
        id: 'ORDER-2',
        total: 25000,
        paymentType: 'Cash',
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            orderId: 'ORDER-2',
            productId: w.burgerId,
            qty: 3,
            price: 25000,
          ),
        ],
      );

      await invService.processOrderPaid(order);
      await invService.processOrderPaid(order); // takror

      expect(await productQty(w.burgerId), 7); // faqat bir marta
    });

    test('qaytarish tayyor sonni tiklaydi (xomashyo qaytarilmaydi)', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);
      final meatAfterProduce = await ingredientStock(w.meatId);

      final order = Order(
        id: 'ORDER-3',
        total: 50000,
        paymentType: 'Cash',
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            orderId: 'ORDER-3',
            productId: w.burgerId,
            qty: 2,
            price: 25000,
          ),
        ],
      );

      await invService.processOrderPaid(order);
      expect(await productQty(w.burgerId), 8);

      // Deadlock bo'lmasligi ham shu yerda tekshiriladi: reverseOrderPaid
      // tranzaksiya ichida flagni o'qiydi.
      await invService.reverseOrderPaid(order);

      expect(await productQty(w.burgerId), 10);
      expect(await ingredientStock(w.meatId), meatAfterProduce);
    });
  });

  group('Kirim / Chiqim va tannarx', () {
    test('kirim og\'irlikli o\'rtacha tannarxni hisoblaydi', () async {
      final id = await invRepo.insertIngredient(
        Ingredient(name: 'Yog\'', baseUnit: 'ml'),
      );

      await invRepo.stockIn(ingredientId: id, qty: 100, cost: 10);
      expect(await ingredientAvgCost(id), 10);

      // 100×10 + 300×20 = 7000 / 400 = 17.5
      await invRepo.stockIn(ingredientId: id, qty: 300, cost: 20);
      expect(await ingredientAvgCost(id), 17.5);
    });

    test('tannarxsiz kirim eski o\'rtachani NOLGA TUSHIRMAYDI', () async {
      final id = await invRepo.insertIngredient(
        Ingredient(name: 'Tuz', baseUnit: 'g'),
      );

      await invRepo.stockIn(ingredientId: id, qty: 100, cost: 50);
      expect(await ingredientAvgCost(id), 50);

      // Tannarx kiritilmadi — avg_cost saqlanishi kerak.
      await invRepo.stockIn(ingredientId: id, qty: 100);
      expect(await ingredientAvgCost(id), 50);
      expect(await ingredientStock(id), 200);
    });

    test('resale kirim son va tannarxni yangilaydi', () async {
      final w = await setupWorld();

      // 50 dona (avg 0) + 50 dona × 5000 → 2500
      await invRepo.resaleStockIn(
        productId: w.colaId,
        qty: 50,
        cost: 5000,
        supplier: 'Coca-Cola',
      );

      expect(await productQty(w.colaId), 100);
      expect(await productAvgCost(w.colaId), 2500);

      final db = await dbHelper.database;
      final rows = await db.query(
        'product_movements',
        where: 'type = ?',
        whereArgs: ['PURCHASE'],
      );
      expect(rows.first['supplier'], 'Coca-Cola');
    });

    test('applyStockBatch hammasini bitta tranzaksiyada yozadi', () async {
      final w = await setupWorld();

      await invRepo.applyStockBatch([
        StockBatchLine(
          kind: StockItemKind.ingredient,
          itemId: w.meatId,
          direction: StockDirection.inbound,
          qty: 1000,
          cost: 100,
          supplier: 'Bozor',
        ),
        StockBatchLine(
          kind: StockItemKind.product,
          itemId: w.colaId,
          direction: StockDirection.inbound,
          qty: 10,
          cost: 5000,
        ),
        StockBatchLine(
          kind: StockItemKind.ingredient,
          itemId: w.breadId,
          direction: StockDirection.outbound,
          qty: 5,
          note: 'buzildi',
        ),
      ]);

      expect(await ingredientStock(w.meatId), 6000);
      expect(await productQty(w.colaId), 60);
      expect(await ingredientStock(w.breadId), 95);
    });

    test('tayyor mahsulot chiqimi (waste)', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      await invRepo.productWaste(
        productId: w.burgerId,
        qty: 3,
        note: 'qolib ketdi',
      );

      expect(await productQty(w.burgerId), 7);
    });
  });

  group('Inventarizatsiya', () {
    test('qoldiqni realga tenglashtiradi va farqni ADJUST qilib yozadi', () async {
      final w = await setupWorld();

      // Tizimda 5000 g, aslida 4800 g chiqdi.
      await invRepo.reconcileIngredients({w.meatId: 4800});

      expect(await ingredientStock(w.meatId), 4800);

      final db = await dbHelper.database;
      final rows = await db.query(
        'stock_movements',
        where: 'type = ? AND ingredient_id = ?',
        whereArgs: ['ADJUST', w.meatId],
      );
      expect(rows.length, 1);
      expect((rows.first['qty'] as num).toDouble(), -200); // farq ishorali
      expect(rows.first['reason'], 'inventory');
    });

    test('mahsulot inventarizatsiyasi ortiqcha farqni ham yozadi', () async {
      final w = await setupWorld();

      await invRepo.reconcileProducts({w.colaId: 55});

      expect(await productQty(w.colaId), 55);
      final db = await dbHelper.database;
      final rows = await db.query(
        'product_movements',
        where: 'type = ? AND product_id = ?',
        whereArgs: ['ADJUST', w.colaId],
      );
      expect((rows.first['qty'] as num).toDouble(), 5);
    });
  });

  group('Tarix va food-cost', () {
    test('getHistory xomashyo va mahsulot harakatlarini birlashtiradi', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 5)]);
      await invRepo.resaleStockIn(productId: w.colaId, qty: 10, cost: 5000);

      final all = await invRepo.getHistory();
      final sources = all.map((r) => r['source']).toSet();
      expect(sources, containsAll(['ingredient', 'product']));

      // Tur bo'yicha filtr
      final produceOnly = await invRepo.getHistory(types: ['PRODUCE']);
      expect(produceOnly.length, 1);
      expect(produceOnly.first['item_name'], 'Burger');

      // Manba bo'yicha filtr
      final ingredientsOnly = await invRepo.getHistory(source: 'ingredient');
      expect(ingredientsOnly.every((r) => r['source'] == 'ingredient'), isTrue);

      // Birlik bo'yicha filtr
      final meatOnly = await invRepo.getHistory(
        source: 'ingredient',
        itemId: w.meatId,
      );
      expect(meatOnly.every((r) => r['item_name'] == 'Go\'sht'), isTrue);
    });

    test('recipeCost = Σ(qty × avg_cost) / yield_qty', () async {
      final w = await setupWorld();
      // go'sht avg_cost = 80/g, non = 2000/dona (setupWorld dagi kirimdan)
      // 150 × 80 + 1 × 2000 = 14000, yield 1 → 14000
      expect(await invRepo.recipeCost(w.burgerId), 14000);
    });

    test('getRecipeCosts bitta so\'rovda bir nechta mahsulotni beradi', () async {
      final w = await setupWorld();
      final costs = await invRepo.getRecipeCosts();
      expect(costs[w.burgerId], 14000);
      expect(costs.containsKey(w.colaId), isFalse); // retsepti yo'q
    });

    test('retsepti yo\'q mahsulotda recipeCost null', () async {
      final w = await setupWorld();
      expect(await invRepo.recipeCost(w.colaId), isNull);
    });
  });
}

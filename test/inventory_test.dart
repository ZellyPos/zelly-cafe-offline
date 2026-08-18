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
      final burgerBefore = await productQty(w.burgerId);
      final colaBefore = await productQty(w.colaId);

      await invService.processOrderPaid(order);

      // ⭐ To'lov qoldiqqa TEGMAYDI — chegirish faqat tasdiqlashda bo'ladi.
      expect(await productQty(w.burgerId), burgerBefore);
      expect(await productQty(w.colaId), colaBefore);

      // Xomashyo ham o'zgarmagan (u faqat "Pishirish"da chegiriladi).
      expect(await ingredientStock(w.meatId), meatAfterProduce);
      expect(await ingredientStock(w.breadId), breadAfterProduce);
    });

    test('chegirish tasdiqlashda, to\'lov uni takrorlamaydi', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      final order = Order(
        id: 'ORDER-1B',
        total: 50000,
        paymentType: 'Cash',
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            orderId: 'ORDER-1B',
            productId: w.burgerId,
            qty: 2,
            price: 25000,
          ),
        ],
      );

      // 1. Tasdiqlash — aynan shu yerda kamayadi.
      await invService.consumeOnConfirm('ORDER-1B', [
        (productId: w.burgerId, qty: 2),
      ]);
      expect(await productQty(w.burgerId), 8);

      // 2. To'lov — hech narsa o'zgarmasligi kerak.
      await invService.processOrderPaid(order);
      expect(await productQty(w.burgerId), 8);
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

      // Tasdiqlashda chegiriladi.
      await invService.consumeOnConfirm('ORDER-2', [
        (productId: w.burgerId, qty: 3),
      ]);
      expect(await productQty(w.burgerId), 7);

      // To'lov necha marta chaqirilsa ham qoldiq o'zgarmaydi.
      await invService.processOrderPaid(order);
      await invService.processOrderPaid(order); // takror

      expect(await productQty(w.burgerId), 7);
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

      // Haqiqiy oqim: avval tasdiqlash (qoldiq kamayadi), keyin to'lov.
      await invService.consumeOnConfirm('ORDER-3', [
        (productId: w.burgerId, qty: 2),
      ]);
      expect(await productQty(w.burgerId), 8);

      await invService.processOrderPaid(order);
      expect(await productQty(w.burgerId), 8); // to'lov tegmaydi

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

    test('chiqim qoldiqdan ko\'p bo\'lsa qoldiq manfiyga tushmaydi', () async {
      final w = await setupWorld(breadQty: 10);

      await expectLater(
        invRepo.stockOut(ingredientId: w.breadId, qty: 15),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await ingredientStock(w.breadId), 10);
    });

    test('mahsulot chiqimi qoldiqdan oshsa rad etiladi', () async {
      final w = await setupWorld();

      await expectLater(
        invRepo.productWaste(productId: w.colaId, qty: 51),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await productQty(w.colaId), 50);
    });

    test('to\'plamda bitta chiqim yetmasa hammasi bekor bo\'ladi', () async {
      final w = await setupWorld(meatQty: 5000, breadQty: 10);

      await expectLater(
        invRepo.applyStockBatch([
          StockBatchLine(
            kind: StockItemKind.ingredient,
            itemId: w.meatId,
            direction: StockDirection.outbound,
            qty: 1000,
          ),
          StockBatchLine(
            kind: StockItemKind.ingredient,
            itemId: w.breadId,
            direction: StockDirection.outbound,
            qty: 999,
          ),
        ]),
        throwsA(isA<InsufficientStockException>()),
      );

      // Birinchi qator ham yozilmasligi kerak — bitta tranzaksiya.
      expect(await ingredientStock(w.meatId), 5000);
      expect(await ingredientStock(w.breadId), 10);
    });

    test('bitta birlik ikki qatorda bo\'lsa miqdorlar jamlanadi', () async {
      final w = await setupWorld(breadQty: 10);

      await expectLater(
        invRepo.applyStockBatch([
          StockBatchLine(
            kind: StockItemKind.ingredient,
            itemId: w.breadId,
            direction: StockDirection.outbound,
            qty: 6,
          ),
          StockBatchLine(
            kind: StockItemKind.ingredient,
            itemId: w.breadId,
            direction: StockDirection.outbound,
            qty: 6,
          ),
        ]),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await ingredientStock(w.breadId), 10);
    });

    test('soni yuritilmaydigan mahsulotga chiqim cheklovi qo\'llanmaydi',
        () async {
      final untrackedId = await dbHelper.insert('products', {
        'name': 'Choy',
        'price': 3000,
        'category': 'Drinks',
        'product_type': 'resale',
        'quantity': null,
        'is_active': 1,
      });

      // `quantity IS NULL` — soni hisobga olinmaydi, xato tashlanmaydi.
      await invRepo.productWaste(productId: untrackedId, qty: 5);

      final db = await dbHelper.database;
      final rows = await db.query(
        'product_movements',
        where: 'product_id = ? AND type = ?',
        whereArgs: [untrackedId, 'WASTE'],
      );
      expect(rows.length, 1);
    });

    test('o\'lchov birligi g/ml/pcs bilan cheklanmaydi', () async {
      // Eski sxemada `CHECK (base_unit IN ('g','ml','pcs'))` bor edi —
      // 'kg' bilan xomashyo qo'shish xato berardi (v56 da olib tashlandi).
      final id = await invRepo.insertIngredient(
        Ingredient(name: 'Un', baseUnit: 'kg', minStock: 5),
      );
      final db = await dbHelper.database;
      final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['base_unit'], 'kg');

      final id2 = await invRepo.insertIngredient(
        Ingredient(name: 'Tuxum', baseUnit: 'dona'),
      );
      expect(id2, isPositive);
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

  group('Buyurtmani tasdiqlash (§8)', () {
    test('tasdiqlanganda tayyor son kamayadi', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      await invService.consumeOnConfirm('ORDER-C1', [
        (productId: w.burgerId, qty: 3),
        (productId: w.colaId, qty: 2),
      ]);

      expect(await productQty(w.burgerId), 7);
      expect(await productQty(w.colaId), 48);

      // Xomashyo tegilmaydi — u pishirishda chegirilgan.
      expect(await ingredientStock(w.meatId), 5000 - 1500);
    });

    test('qoldiq yetmasa hech narsa yozilmaydi (rollback)', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 2)]);

      await expectLater(
        invService.consumeOnConfirm('ORDER-C2', [
          (productId: w.burgerId, qty: 5), // faqat 2 ta bor
          (productId: w.colaId, qty: 1), // bu yetadi, lekin bekor bo'ladi
        ]),
        throwsA(isA<InsufficientStockException>()),
      );

      // Qisman yozilish bo'lmasligi shart — buyurtma tasdiqlanmaydi.
      expect(await productQty(w.burgerId), 2);
      expect(await productQty(w.colaId), 50);
    });

    test('yetishmovchilik tafsilotlari beriladi', () async {
      final w = await setupWorld();

      try {
        await invService.consumeOnConfirm('ORDER-C3', [
          (productId: w.burgerId, qty: 4),
        ]);
        fail('InsufficientStockException tashlanishi kerak edi');
      } on InsufficientStockException catch (e) {
        expect(e.shortages.length, 1);
        expect(e.shortages.first.name, 'Burger');
        expect(e.shortages.first.need, 4);
        expect(e.shortages.first.onHand, 0);
      }
    });

    test('manfiy delta qoldiqni qaytaradi', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);
      await invService.consumeOnConfirm('ORDER-C4', [
        (productId: w.burgerId, qty: 4),
      ]);
      expect(await productQty(w.burgerId), 6);

      // Buyurtmada son 4 dan 1 ga kamaytirildi → 3 ta qaytadi.
      await invService.consumeOnConfirm('ORDER-C4', [
        (productId: w.burgerId, qty: -3),
      ]);
      expect(await productQty(w.burgerId), 9);
    });

    test('to\'lov tasdiqlangan qismni IKKINCHI marta chegirmaydi', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      // Tasdiqlash: 2 ta, keyin qo'shimcha 1 ta (jami 3).
      await invService.consumeOnConfirm('ORDER-C5', [
        (productId: w.burgerId, qty: 2),
      ]);
      await invService.consumeOnConfirm('ORDER-C5', [
        (productId: w.burgerId, qty: 1),
      ]);
      expect(await productQty(w.burgerId), 7);

      // To'lovda buyurtmaning to'liq soni (3) keladi — qo'shimcha
      // chegirish bo'lmasligi kerak.
      await invService.processOrderPaid(
        Order(
          id: 'ORDER-C5',
          total: 75000,
          paymentType: 'Cash',
          createdAt: DateTime.now(),
          items: [
            OrderItem(
              orderId: 'ORDER-C5',
              productId: w.burgerId,
              qty: 3,
              price: 25000,
            ),
          ],
        ),
      );

      expect(await productQty(w.burgerId), 7);
    });

    test('tasdiqlanmagan qism to\'lovda CHEGIRILMAYDI', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      // Buyurtmada 3 ta, lekin faqat 1 tasi tasdiqlangan.
      await invService.consumeOnConfirm('ORDER-C6', [
        (productId: w.burgerId, qty: 1),
      ]);
      await invService.processOrderPaid(
        Order(
          id: 'ORDER-C6',
          total: 75000,
          paymentType: 'Cash',
          createdAt: DateTime.now(),
          items: [
            OrderItem(
              orderId: 'ORDER-C6',
              productId: w.burgerId,
              qty: 3,
              price: 25000,
            ),
          ],
        ),
      );

      // Faqat tasdiqlangan 1 ta chegirilgan. To'lov qolgan 2 tasini
      // chegirmaydi — qoldiq faqat "Tasdiqlash"da kamayadi.
      expect(await productQty(w.burgerId), 9);
    });

    test('son yuritilmaydigan mahsulot (quantity NULL) bloklamaydi', () async {
      await setupWorld();
      // quantity berilmagan — bu mahsulotning soni yuritilmaydi.
      final teaId = await dbHelper.insert('products', {
        'name': 'Choy',
        'price': 3000,
        'category': 'Drinks',
        'is_active': 1,
      });

      // Xato tashlanmasligi va quantity NULL qolishi kerak.
      await invService.consumeOnConfirm('ORDER-C8', [
        (productId: teaId, qty: 5),
      ]);

      final db = await dbHelper.database;
      final rows = await db.query('products', where: 'id = ?', whereArgs: [teaId]);
      expect(rows.first['quantity'], isNull);
    });

    test('to\'plam (set) tarkibidagi mahsulotlar chegiriladi', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 10)]);

      final setId = await dbHelper.insert('products', {
        'name': 'Lanch to\'plami',
        'price': 30000,
        'category': 'Sets',
        'is_set': 1,
        'is_active': 1,
      });
      final db = await dbHelper.database;
      await db.insert('product_bundles', {
        'bundle_id': setId,
        'product_id': w.burgerId,
        'quantity': 1.0,
      });
      await db.insert('product_bundles', {
        'bundle_id': setId,
        'product_id': w.colaId,
        'quantity': 2.0,
      });

      await invService.consumeOnConfirm('ORDER-C7', [
        (productId: setId, qty: 2),
      ]);

      expect(await productQty(w.burgerId), 8); // 10 - 2×1
      expect(await productQty(w.colaId), 46); // 50 - 2×2
    });
  });

  group('Mahsulot turi', () {
    test('resale ga o\'tkazilganda retsept o\'chadi', () async {
      final w = await setupWorld();
      expect(await invRepo.getRecipeForProduct(w.burgerId), isNotNull);

      await invRepo.setProductType(w.burgerId, 'resale');

      final db = await dbHelper.database;
      final rows = await db.query(
        'products',
        columns: ['product_type'],
        where: 'id = ?',
        whereArgs: [w.burgerId],
      );
      expect(rows.first['product_type'], 'resale');
      // Retseptsiz qolishi shart — aks holda pishirish ro'yxatida turardi.
      expect(await invRepo.getRecipeForProduct(w.burgerId), isNull);

      // Endi resale ro'yxatiga tushadi, prepared dan chiqadi
      final resale = await invRepo.getResaleProducts();
      expect(resale.any((m) => m['id'] == w.burgerId), isTrue);
      final prepared = await invRepo.getPreparedProducts();
      expect(prepared.any((m) => m['id'] == w.burgerId), isFalse);
    });

    test('prepared ga qaytarilganda retsept o\'chirilmaydi', () async {
      final w = await setupWorld();

      await invRepo.setProductType(w.colaId, 'prepared');

      final prepared = await invRepo.getPreparedProducts();
      expect(prepared.any((m) => m['id'] == w.colaId), isTrue);
      // Burgerning retsepti tegilmagan bo'lishi kerak
      expect(await invRepo.getRecipeForProduct(w.burgerId), isNotNull);
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

    test('getHistory sahifalaydi, getHistoryCount jamini beradi', () async {
      final w = await setupWorld();
      // setupWorld o'zi ham kirim yozadi — shuning uchun jamini o'lchab olamiz.
      final before = await invRepo.getHistoryCount();
      for (var i = 0; i < 12; i++) {
        await invRepo.stockIn(ingredientId: w.meatId, qty: 10, cost: 80);
      }

      final total = await invRepo.getHistoryCount();
      expect(total, before + 12);

      final page1 = await invRepo.getHistory(limit: 5, offset: 0);
      final page2 = await invRepo.getHistory(limit: 5, offset: 5);
      expect(page1.length, 5);
      expect(page2.length, 5);
      // Sahifalar bir-birini takrorlamaydi.
      final ids1 = page1.map((r) => '${r['source']}:${r['id']}').toSet();
      final ids2 = page2.map((r) => '${r['source']}:${r['id']}').toSet();
      expect(ids1.intersection(ids2), isEmpty);

      // Oxirgi sahifa qisqaroq.
      final last = await invRepo.getHistory(
        limit: 5,
        offset: (total ~/ 5) * 5,
      );
      expect(last.length, total % 5);

      // Filtr `count` ga ham qo'llanadi.
      final inCount = await invRepo.getHistoryCount(types: ['IN']);
      final inRows = await invRepo.getHistory(types: ['IN'], limit: 1000);
      expect(inCount, inRows.length);
    });

    test('pishirish xomashyosi tarixda SARF (CONSUME) va mahsulot nomi bilan',
        () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 2)]);
      // Oddiy chiqim — sarfdan farqlanishi kerak.
      await invRepo.stockOut(ingredientId: w.meatId, qty: 10, note: 'buzildi');

      final meat = await invRepo.getHistory(
        source: 'ingredient',
        itemId: w.meatId,
      );
      final consume = meat.where((r) => r['type'] == 'CONSUME').toList();
      expect(consume.length, 1);
      expect(consume.first['ref_name'], 'Burger'); // qaysi mahsulot uchun
      expect(consume.first['qty'], 300); // 150 g × 2

      // `CONSUME` filtri faqat pishirish sarfini beradi.
      final onlyConsume = await invRepo.getHistory(types: ['CONSUME']);
      expect(onlyConsume.length, 2); // go'sht + non
      expect(onlyConsume.every((r) => r['ref_name'] == 'Burger'), isTrue);
      expect(await invRepo.getHistoryCount(types: ['CONSUME']), 2);

      // `OUT` filtri esa sarfni ichiga OLMAYDI — faqat haqiqiy chiqim.
      final onlyOut = await invRepo.getHistory(types: ['OUT']);
      expect(onlyOut.length, 1);
      expect(onlyOut.first['note'], 'buzildi');
      expect(await invRepo.getHistoryCount(types: ['OUT']), 1);
    });

    test('getHistory qidiruvi: nom, izoh va pishirilgan mahsulot bo\'yicha',
        () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 1)]);
      await invRepo.stockOut(ingredientId: w.meatId, qty: 5, note: 'muzlatkich');

      // Xomashyo nomi bo'yicha
      final byName = await invRepo.getHistory(search: 'sht'); // Go'sht
      expect(byName.isNotEmpty, isTrue);
      expect(byName.every((r) => r['item_name'] == 'Go\'sht'), isTrue);

      // Izoh bo'yicha
      final byNote = await invRepo.getHistory(search: 'muzlat');
      expect(byNote.length, 1);
      expect(byNote.first['note'], 'muzlatkich');

      // Sarf qatorlari pishirilgan mahsulot nomi bo'yicha ham topiladi.
      final byProduct = await invRepo.getHistory(
        source: 'ingredient',
        search: 'Burger',
      );
      expect(byProduct.length, 2); // go'sht + non sarfi
      expect(byProduct.every((r) => r['type'] == 'CONSUME'), isTrue);

      // Sanoq ro'yxat bilan mos.
      expect(
        await invRepo.getHistoryCount(search: 'muzlat'),
        byNote.length,
      );
      expect(await invRepo.getHistory(search: 'yo\'q-bunday'), isEmpty);
    });

    test('o\'chirilgan xomashyoning tarixi qoladi (§20)', () async {
      final w = await setupWorld();
      await invService.produce([(productId: w.burgerId, count: 2)]);
      await invRepo.stockOut(ingredientId: w.meatId, qty: 5, note: 'muzlatkich');

      final before = await invRepo.getHistoryCount();
      final meatBefore = await invRepo.getHistory(
        source: 'ingredient',
        itemId: w.meatId,
      );
      expect(meatBefore, isNotEmpty);

      await invRepo.deleteIngredient(w.meatId);

      // Ro'yxatlardan chiqadi...
      final active = await invRepo.getAllIngredients();
      expect(active.any((i) => i.id == w.meatId), isFalse);
      final withStock = await invRepo.getIngredientsWithStock();
      expect(withStock.any((r) => r['id'] == w.meatId), isFalse);

      // ...lekin tarixdan CHIQMAYDI.
      expect(await invRepo.getHistoryCount(), before);
      final meatAfter = await invRepo.getHistory(
        source: 'ingredient',
        itemId: w.meatId,
      );
      expect(meatAfter.length, meatBefore.length);
      expect(meatAfter.first['item_name'], 'Go\'sht');
      expect(meatAfter.any((r) => r['note'] == 'muzlatkich'), isTrue);

      // Izoh va sarf bo'yicha qidiruv ham ishlayveradi.
      expect(await invRepo.getHistory(search: 'muzlat'), hasLength(1));
      final consume = await invRepo.getHistory(types: ['CONSUME']);
      expect(consume.any((r) => r['item_id'] == w.meatId), isTrue);
    });

    test('o\'chirilgan xomashyo faol retseptdan olib tashlanadi', () async {
      final w = await setupWorld();
      await invRepo.deleteIngredient(w.meatId);

      final recipe = await invRepo.getRecipeForProduct(w.burgerId);
      expect(recipe, isNotNull);
      expect(recipe!.items.any((it) => it.ingredientId == w.meatId), isFalse);
      expect(recipe.items.any((it) => it.ingredientId == w.breadId), isTrue);
    });

    test('o\'chirilgan mahsulotning tarixi qoladi (§20)', () async {
      final w = await setupWorld();
      await invRepo.resaleStockIn(productId: w.colaId, qty: 10, cost: 5000);

      final before = await invRepo.getHistoryCount();
      final db = await dbHelper.database;
      await db.delete('products', where: 'id = ?', whereArgs: [w.colaId]);

      expect(await invRepo.getHistoryCount(), before);
      final rows = await invRepo.getHistory(
        source: 'product',
        itemId: w.colaId,
      );
      expect(rows, isNotEmpty);
      // Mahsulot qatori yo'q, lekin nom snapshot'i tarixda qolgan.
      expect(rows.first['item_name'], 'Cola 0.5');
      expect(rows.first['qty'], 10);

      // Snapshot bo'yicha qidiruv ham ishlaydi.
      final found = await invRepo.getHistory(source: 'product', search: 'Cola');
      expect(found, isNotEmpty);
    });

    test('snapshot: nom o\'zgarsa tarixda joriy nom ko\'rinadi', () async {
      final w = await setupWorld();
      await invRepo.resaleStockIn(productId: w.colaId, qty: 10, cost: 5000);

      final db = await dbHelper.database;
      // Snapshot yozuv kiritilganda saqlanadi...
      final snap = await db.query(
        'product_movements',
        where: 'product_id = ?',
        whereArgs: [w.colaId],
      );
      expect(snap.first['item_name'], 'Cola 0.5');

      // ...lekin mahsulot mavjud ekan, tarixda JORIY nom ustun turadi.
      await db.update(
        'products',
        {'name': 'Coca-Cola 0.5'},
        where: 'id = ?',
        whereArgs: [w.colaId],
      );
      final rows = await invRepo.getHistory(
        source: 'product',
        itemId: w.colaId,
      );
      expect(rows.first['item_name'], 'Coca-Cola 0.5');
    });

    test('snapshot: o\'chirilgan xomashyoning birligi saqlanadi', () async {
      final w = await setupWorld();
      await invRepo.stockOut(ingredientId: w.meatId, qty: 5, note: 'buzildi');

      final db = await dbHelper.database;
      // Xomashyo qatorini butunlay yo'qotamiz (eski hard-delete bazalar).
      await db.delete('ingredients', where: 'id = ?', whereArgs: [w.meatId]);

      final rows = await invRepo.getHistory(
        source: 'ingredient',
        itemId: w.meatId,
      );
      expect(rows, isNotEmpty);
      expect(rows.first['item_name'], 'Go\'sht');
      expect(rows.first['unit'], 'g');
    });

    test('harakat jurnallarida CASCADE bog\'lanish yo\'q (§20)', () async {
      await setupWorld();
      final db = await dbHelper.database;
      for (final table in ['stock_movements', 'product_movements']) {
        final schema = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        expect(schema, isNotEmpty, reason: '$table topilmadi');
        expect(
          (schema.first['sql'] as String).toUpperCase(),
          isNot(contains('CASCADE')),
          reason: '$table — ledger, o\'chirish kaskadi bo\'lmasligi kerak',
        );
      }
    });

    /// §19: eski yozuvlarni tozalash. Sana bo'yicha — element o'chirilgani
    /// sababli emas (§20).
    group('Retention (§19)', () {
      /// Berilgan yozuvlarni "eski" qilib qo'yadi.
      Future<void> ageAll(String createdAt) async {
        final db = await dbHelper.database;
        await db.update('stock_movements', {'created_at': createdAt});
        await db.update('product_movements', {'created_at': createdAt});
      }

      test('muddati o\'tgan yozuvlar o\'chadi, yangilari qoladi', () async {
        final w = await setupWorld();
        await invRepo.resaleStockIn(productId: w.colaId, qty: 10, cost: 5000);
        await ageAll('2023-01-01T10:00:00.000');

        // Chegaradan keyingi yangi yozuv.
        await invRepo.stockIn(ingredientId: w.meatId, qty: 100, cost: 80);
        final freshCount = await invRepo.getHistoryCount();

        final removed = await invRepo.purgeHistoryOlderThan(
          24,
          now: DateTime(2026, 8, 17),
        );
        expect(removed.ingredient, greaterThan(0));
        expect(removed.product, 1);

        final left = await invRepo.getHistory(limit: 1000);
        expect(left, hasLength(1)); // faqat yangi kirim
        expect(left.first['qty'], 100);
        expect(freshCount, greaterThan(left.length));
      });

      test('0 oy = cheksiz saqlash, hech nima o\'chmaydi', () async {
        final w = await setupWorld();
        await invRepo.resaleStockIn(productId: w.colaId, qty: 10, cost: 5000);
        await ageAll('2015-01-01T10:00:00.000');
        final before = await invRepo.getHistoryCount();

        final removed = await invRepo.purgeHistoryOlderThan(0);
        expect(removed.ingredient, 0);
        expect(removed.product, 0);
        expect(await invRepo.getHistoryCount(), before);
      });

      test('tarixi qolgan o\'chirilgan xomashyo saqlanadi', () async {
        final w = await setupWorld();
        await invRepo.deleteIngredient(w.meatId);

        // Tarix hali muddati ichida — xomashyo qatori ham turishi kerak,
        // aks holda undagi yozuvlar nomsiz qolardi.
        await invRepo.purgeHistoryOlderThan(24, now: DateTime(2026, 8, 17));

        final db = await dbHelper.database;
        final rows = await db.query(
          'ingredients',
          where: 'id = ?',
          whereArgs: [w.meatId],
        );
        expect(rows, hasLength(1));
        expect(rows.first['is_active'], 0);
      });

      test('tarixi tugagan o\'chirilgan xomashyo fizik yo\'q qilinadi',
          () async {
        final w = await setupWorld();
        await invRepo.deleteIngredient(w.meatId);
        await ageAll('2015-01-01T10:00:00.000');

        await invRepo.purgeHistoryOlderThan(24, now: DateTime(2026, 8, 17));

        final db = await dbHelper.database;
        expect(
          await db.query('ingredients', where: 'id = ?', whereArgs: [w.meatId]),
          isEmpty,
        );
        expect(
          await db.query(
            'ingredient_stock',
            where: 'ingredient_id = ?',
            whereArgs: [w.meatId],
          ),
          isEmpty,
        );
        // Faol xomashyoga tegilmagan.
        expect(
          await db.query('ingredients', where: 'id = ?', whereArgs: [w.breadId]),
          hasLength(1),
        );
      });
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

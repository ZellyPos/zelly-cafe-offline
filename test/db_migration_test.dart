import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tezzro/core/database_helper.dart';

/// To'liq bazani quramiz, keyin `ingredients` ni **eski (v55) CHECK li**
/// ko'rinishga qaytarib `user_version = 55` qo'yamiz. Qayta ochilganda v56
/// migratsiyasi ishlashi kerak.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('v55 -> v56: base_unit CHECK olib tashlanadi, ma\'lumot saqlanadi',
      () async {
    final dir = await databaseFactory.getDatabasesPath();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir,
    );

    final path = '$dir/mig_v56_test.db';
    await databaseFactory.deleteDatabase(path);

    // 1. To'liq baza (joriy versiya).
    DatabaseHelper.databasePathOverride = 'mig_v56_test.db';
    await DatabaseHelper.instance.close();
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.close();

    // 2. `ingredients` ni eski CHECK li ko'rinishga qaytaramiz + v55.
    final raw = await databaseFactory.openDatabase(path);
    await raw.execute('DROP TABLE ingredients');
    await raw.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        base_unit TEXT NOT NULL CHECK (base_unit IN ('g', 'ml', 'pcs')),
        min_stock REAL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        image_path TEXT,
        avg_cost REAL DEFAULT 0
      )
    ''');
    await raw.insert('ingredients', {
      'name': "Go'sht",
      'base_unit': 'g',
      'min_stock': 1000.0,
      'avg_cost': 80.0,
    });
    await raw.insert('ingredient_stock', {
      'ingredient_id': 1,
      'on_hand': 5000.0,
    });
    // Eski sxemada 'kg' xato beradi — aynan shu bug edi.
    var oldRejected = false;
    try {
      await raw.insert('ingredients', {'name': 'Un', 'base_unit': 'kg'});
    } catch (_) {
      oldRejected = true;
    }
    expect(oldRejected, isTrue);
    await raw.execute('PRAGMA user_version = 55');
    await raw.close();

    // 3. Ilova ochilishi — migratsiya v55 → v56.
    await DatabaseHelper.instance.close();
    final db = await DatabaseHelper.instance.database;
    expect(
      (await db.rawQuery('PRAGMA user_version')).first['user_version'],
      greaterThanOrEqualTo(56),
    );

    // 4. Ma'lumot joyida.
    final rows = await db.query('ingredients', where: 'id = 1');
    expect(rows.first['name'], "Go'sht");
    expect(rows.first['avg_cost'], 80.0);
    final stock = await db.query('ingredient_stock', where: 'ingredient_id = 1');
    expect((stock.first['on_hand'] as num).toDouble(), 5000.0);

    // 5. Endi 'kg' va ixtiyoriy birlik qabul qilinadi.
    expect(
      await db.insert('ingredients', {'name': 'Un', 'base_unit': 'kg'}),
      isPositive,
    );
    expect(
      await db.insert('ingredients', {'name': 'Tuxum', 'base_unit': 'dona'}),
      isPositive,
    );

    await DatabaseHelper.instance.close();
  });

  /// §20: harakat jurnallaridan `ON DELETE CASCADE` olib tashlanadi —
  /// mavjud yozuvlar bir donasi ham yo'qolmasligi kerak.
  test('v56 -> v57: harakat jurnallaridan CASCADE olinadi, yozuvlar qoladi',
      () async {
    final dir = await databaseFactory.getDatabasesPath();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir,
    );

    final path = '$dir/mig_v57_test.db';
    await databaseFactory.deleteDatabase(path);

    DatabaseHelper.databasePathOverride = 'mig_v57_test.db';
    await DatabaseHelper.instance.close();
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.close();

    // Jurnallarni eski (CASCADE li) ko'rinishga qaytaramiz + v56.
    final raw = await databaseFactory.openDatabase(path);
    await raw.execute('DROP TABLE stock_movements');
    await raw.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_id INTEGER,
        type TEXT NOT NULL CHECK (type IN ('IN', 'OUT', 'ADJUST', 'RETURN')),
        qty REAL NOT NULL,
        reason TEXT,
        ref_table TEXT,
        ref_id TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        created_by INTEGER,
        cost_price REAL DEFAULT 0,
        supplier TEXT,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE
      )
    ''');
    await raw.execute('DROP TABLE product_movements');
    await raw.execute('''
      CREATE TABLE product_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('PRODUCE','PURCHASE','SALE','WASTE','ADJUST')),
        qty REAL NOT NULL,
        ref_table TEXT,
        ref_id TEXT,
        cost_price REAL DEFAULT 0,
        supplier TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        created_by INTEGER,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
    await raw.insert('stock_movements', {
      'ingredient_id': 7,
      'type': 'IN',
      'qty': 1500.0,
      'note': 'eski kirim',
      'created_at': '2026-01-05T10:00:00.000',
      'cost_price': 80.0,
      'supplier': 'Bozor',
    });
    await raw.insert('product_movements', {
      'product_id': 3,
      'type': 'PRODUCE',
      'qty': 4.0,
      'created_at': '2026-01-05T11:00:00.000',
    });
    await raw.execute('PRAGMA user_version = 56');
    await raw.close();

    // Ilova ochilishi — migratsiya v56 → v57.
    await DatabaseHelper.instance.close();
    final db = await DatabaseHelper.instance.database;
    expect(
      (await db.rawQuery('PRAGMA user_version')).first['user_version'],
      greaterThanOrEqualTo(57),
    );

    for (final table in ['stock_movements', 'product_movements']) {
      final sql = (await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      )).first['sql'] as String;
      expect(sql.toUpperCase(), isNot(contains('CASCADE')), reason: table);
    }

    // Yozuvlar to'liq ko'chgan.
    final sm = await db.query('stock_movements');
    expect(sm, hasLength(1));
    expect(sm.first['ingredient_id'], 7);
    expect(sm.first['note'], 'eski kirim');
    expect((sm.first['cost_price'] as num).toDouble(), 80.0);
    expect(sm.first['supplier'], 'Bozor');

    final pm = await db.query('product_movements');
    expect(pm, hasLength(1));
    expect(pm.first['product_id'], 3);
    expect((pm.first['qty'] as num).toDouble(), 4.0);

    // Indekslar tiklangan.
    final idx = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    )).map((r) => r['name']).toSet();
    expect(idx, contains('idx_stock_movements_lookup'));
    expect(idx, contains('idx_product_movements_lookup'));

    await DatabaseHelper.instance.close();
  });

  /// §20: snapshot ustunlari qo'shiladi va mavjud yozuvlar hozirgi nomlar
  /// bilan to'ldiriladi.
  test('v57 -> v58: nom snapshot ustunlari qo\'shilib to\'ldiriladi', () async {
    final dir = await databaseFactory.getDatabasesPath();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir,
    );

    final path = '$dir/mig_v58_test.db';
    await databaseFactory.deleteDatabase(path);

    DatabaseHelper.databasePathOverride = 'mig_v58_test.db';
    await DatabaseHelper.instance.close();
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.close();

    final raw = await databaseFactory.openDatabase(path);
    final ingId = await raw.insert('ingredients', {
      'name': "Go'sht",
      'base_unit': 'g',
    });
    final prodId = await raw.insert('products', {
      'name': 'Burger',
      'price': 25000.0,
      'category': 'Food',
      'unit': 'dona',
    });
    // Snapshot ustunlarisiz yozilgan eski qatorlar.
    await raw.insert('stock_movements', {
      'ingredient_id': ingId,
      'type': 'IN',
      'qty': 1500.0,
      'created_at': '2026-01-05T10:00:00.000',
    });
    await raw.insert('product_movements', {
      'product_id': prodId,
      'type': 'PRODUCE',
      'qty': 4.0,
      'created_at': '2026-01-05T11:00:00.000',
    });
    await raw.execute('PRAGMA user_version = 57');
    await raw.close();

    await DatabaseHelper.instance.close();
    final db = await DatabaseHelper.instance.database;
    expect(
      (await db.rawQuery('PRAGMA user_version')).first['user_version'],
      greaterThanOrEqualTo(58),
    );

    final sm = (await db.query('stock_movements')).first;
    expect(sm['item_name'], "Go'sht");
    expect(sm['item_unit'], 'g');

    final pm = (await db.query('product_movements')).first;
    expect(pm['item_name'], 'Burger');
    expect(pm['item_unit'], 'dona');

    // §19: retention tozalashi sof `created_at` bo'yicha o'chiradi.
    final idx = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    )).map((r) => r['name']).toSet();
    expect(idx, contains('idx_stock_movements_date'));
    expect(idx, contains('idx_product_movements_date'));

    await DatabaseHelper.instance.close();
  });
}

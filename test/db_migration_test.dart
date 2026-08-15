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
      56,
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
}

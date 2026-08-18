// Ombordagi SQLite bazaga to'g'ridan-to'g'ri so'rov yuborish (ishlab chiqish
// vositasi). Ilovani ochmasdan ma'lumotni ko'rish — masalan test uchun
// admin PIN kodini topish yoki kategoriyalarni tekshirish.
//
//   dart run tool/db_query.dart "SELECT id, name, role FROM users"
//
// Boshqa bazani ko'rish uchun: ZELLY_DB=<yo'l> muhit o'zgaruvchisi.
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Ishlatish: dart run tool/db_query.dart "<SQL>"');
    exit(2);
  }

  sqfliteFfiInit();

  final appData = Platform.environment['APPDATA'];
  final dbPath =
      Platform.environment['ZELLY_DB'] ??
      '$appData/com.example/tezzro/tezzro_pos.db';

  if (!File(dbPath).existsSync()) {
    stderr.writeln('Baza topilmadi: $dbPath');
    stderr.writeln('Ilova hech bo\'lmasa bir marta ishga tushirilganmi?');
    exit(1);
  }

  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
  try {
    final rows = await db.rawQuery(args.join(' '));
    for (final row in rows) {
      stdout.writeln(row);
    }
    stderr.writeln('(${rows.length} qator)');
  } finally {
    await db.close();
  }
}

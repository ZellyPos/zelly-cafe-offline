import '../../core/database_helper.dart';

/// Developer (ma'lumotlar bazasi ko'rish/tahrirlash) vositasi uchun
/// ma'lumotlar qatlami. Bu ataylab umumiy (generik) — istalgan jadval bilan
/// ishlaydi. Faqat developer ekranida ishlatilishi kerak.
class DeveloperRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Foydalanuvchi jadvallari ro'yxati (tizim jadvallarisiz), alfavit bo'yicha.
  Future<List<String>> getTableNames() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'",
    );
    final names = result.map((row) => row['name'] as String).toList();
    names.sort();
    return names;
  }

  Future<List<Map<String, dynamic>>> getTableData(String tableName) async {
    final db = await _dbHelper.database;
    return db.query(tableName);
  }

  Future<void> deleteRow(String tableName, String idColumn, dynamic id) async {
    final db = await _dbHelper.database;
    await db.delete(tableName, where: '$idColumn = ?', whereArgs: [id]);
  }

  Future<void> updateRow(
    String tableName,
    String idColumn,
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    final db = await _dbHelper.database;
    await db.update(tableName, data, where: '$idColumn = ?', whereArgs: [id]);
  }

  Future<void> addRow(String tableName, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert(tableName, data);
  }

  Future<void> executeRawQuery(String query) async {
    final db = await _dbHelper.database;
    await db.execute(query);
  }

  /// Ixtiyoriy SELECT/PRAGMA so'rovini bajarib, natijani qaytaradi.
  Future<List<Map<String, dynamic>>> runRawQuery(String query) async {
    final db = await _dbHelper.database;
    return db.rawQuery(query);
  }

  /// Jadvaldagi yozuvlar sonini qaytaradi.
  Future<int> getRowCount(String tableName) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM "$tableName"');
    return (res.first['c'] as int?) ?? 0;
  }

  /// Ma'lumotlar bazasi fayl yo'lini qaytaradi.
  Future<String> getDatabasePath() => _dbHelper.getDatabasePath();

  /// Ma'lumotlar bazasini yopadi (masalan, tiklashdan oldin).
  Future<void> close() => _dbHelper.close();
}

import '../../core/database_helper.dart';
import '../../models/printer_settings.dart';

/// Printerlar (`printers` jadvali) uchun ma'lumotlar qatlami.
///
/// Eski versiyalar printer sozlamasini `settings` jadvalida saqlagan; migratsiya
/// uchun [getLegacySettings] shu eski ma'lumotni o'qiydi.
class PrinterRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<PrinterSettings>> getPrinters() async {
    final db = await _dbHelper.database;
    final res = await db.query('printers');
    return res.map((m) => PrinterSettings.fromMap(m)).toList();
  }

  /// Eski (legacy) `settings` jadvalidan printer sozlamalarini o'qiydi
  /// (migratsiya uchun).
  Future<Map<String, dynamic>> getLegacySettings() async {
    final db = await _dbHelper.database;
    final rows = await db.query('settings');
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  /// Printerni saqlaydi: `id` null bo'lsa qo'shadi, aks holda yangilaydi.
  Future<void> savePrinter(PrinterSettings printer) async {
    final db = await _dbHelper.database;
    if (printer.id == null) {
      await db.insert('printers', printer.toMap());
    } else {
      await db.update(
        'printers',
        printer.toMap(),
        where: 'id = ?',
        whereArgs: [printer.id],
      );
    }
  }

  Future<void> deletePrinter(int id) async {
    final db = await _dbHelper.database;
    await db.delete('printers', where: 'id = ?', whereArgs: [id]);
  }

  /// Chop etish uchun printerni tanlaydi: avval [selectedId] bo'yicha, keyin
  /// asosiy (`is_main = 1`), keyin birinchisi. Hech biri bo'lmasa `null`.
  Future<PrinterSettings?> resolvePrinter(int? selectedId) async {
    final db = await _dbHelper.database;
    if (selectedId != null) {
      final res = await db.query('printers', where: 'id = ?', whereArgs: [selectedId]);
      if (res.isNotEmpty) return PrinterSettings.fromMap(res.first);
    }
    final main = await db.query('printers', where: 'is_main = 1');
    if (main.isNotEmpty) return PrinterSettings.fromMap(main.first);

    final all = await db.query('printers');
    if (all.isNotEmpty) return PrinterSettings.fromMap(all.first);
    return null;
  }
}

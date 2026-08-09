import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/database_helper.dart';

/// `settings` (kalit-qiymat) jadvali uchun umumiy ma'lumotlar qatlami.
///
/// [AppSettingsProvider] va [ReceiptSettingsProvider] shu repozitoriydan
/// foydalanadi — takrorlanuvchi "upsert" mantiqi shu yerda jamlangan.
class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Barcha sozlamalarni kalit→qiymat map ko'rinishida qaytaradi.
  Future<Map<String, String>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  /// Bitta sozlama qiymatini qaytaradi (topilmasa `null`).
  Future<String?> getValue(String key) async {
    final rows = await _dbHelper.queryByColumn('settings', 'key', key);
    return rows.isNotEmpty ? rows.first['value'] as String? : null;
  }

  /// Upsert: mavjud bo'lsa yangilaydi, aks holda qo'shadi.
  Future<void> setValue(String key, String value) async {
    final existing = await _dbHelper.queryByColumn('settings', 'key', key);
    if (existing.isNotEmpty) {
      await _dbHelper.update('settings', {'value': value}, 'key = ?', [key]);
    } else {
      await _dbHelper.insert('settings', {'key': key, 'value': value});
    }
  }

  /// Faqat yangilaydi (yozuv mavjud deb hisoblaydi, masalan PIN).
  Future<void> updateValue(String key, String value) async {
    await _dbHelper.update('settings', {'value': value}, 'key = ?', [key]);
  }

  Future<void> deleteKey(String key) async {
    await _dbHelper.delete('settings', 'key = ?', [key]);
  }

  /// Kun boshlanish vaqtini (`day_reset_time` sozlamasiga ko'ra) qaytaradi.
  Future<DateTime> getDayStartTime() => _dbHelper.getDayStartTime();

  /// Bir nechta kalit-qiymatni bitta batch'da saqlaydi (replace).
  Future<void> saveAll(Map<String, dynamic> values) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    values.forEach((key, value) {
      batch.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }
}

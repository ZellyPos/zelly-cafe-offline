import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/receipt_settings.dart';
import '../core/database_helper.dart';

class ReceiptSettingsProvider extends ChangeNotifier {
  ReceiptSettings _settings = ReceiptSettings();

  ReceiptSettings get settings => _settings;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  ReceiptSettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings'); // Key, Value

      if (res.isNotEmpty) {
        Map<String, dynamic> dbMap = {};
        for (var row in res) {
          dbMap[row['key'] as String] = row['value'];
        }
        _settings = ReceiptSettings.fromMap(dbMap);
      }
    } catch (e) {
      debugPrint('Error loading receipt settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(ReceiptSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveToDb(newSettings);
  }

  Future<void> _saveToDb(ReceiptSettings settings) async {
    final db = await DatabaseHelper.instance.database;
    final map = settings.toMap();

    final batch = db.batch();
    map.forEach((key, value) {
      batch.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    await batch.commit(noResult: true);
  }
}

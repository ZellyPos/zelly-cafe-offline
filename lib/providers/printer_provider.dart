import 'package:flutter/material.dart';
import '../models/printer_settings.dart';
import '../core/database_helper.dart';
import '../core/printing_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PrinterProvider with ChangeNotifier {
  PrinterSettings _settings = PrinterSettings();
  List<String> _windowsPrinters = [];
  List<String> _legacyUsbPrinters = []; // For fallback
  bool _isLoading = false;

  PrinterSettings get settings => _settings;
  List<String> get windowsPrinters => _windowsPrinters;
  List<String> get legacyUsbPrinters => _legacyUsbPrinters;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('settings');

    if (res.isNotEmpty) {
      Map<String, dynamic> settingsMap = {};
      for (var row in res) {
        settingsMap[row['key'] as String] = row['value'];
      }
      _settings = PrinterSettings.fromMap(settingsMap);
      notifyListeners();
    }
  }

  Future<void> saveSettings(PrinterSettings newSettings) async {
    _settings = newSettings;
    final db = await DatabaseHelper.instance.database;
    final map = _settings.toMap();

    final batch = db.batch();
    map.forEach((key, value) {
      batch.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit();
    notifyListeners();
  }

  Future<void> scanPrinters() async {
    _isLoading = true;
    notifyListeners();

    _windowsPrinters = await PrintingService.getWindowsPrinters();
    _legacyUsbPrinters = await PrintingService.getUsbPrinters();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> testPrint([PrinterSettings? settings]) async {
    return await PrintingService.testPrint(settings: settings ?? _settings);
  }
}

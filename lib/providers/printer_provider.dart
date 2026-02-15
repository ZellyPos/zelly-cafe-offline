import 'package:flutter/material.dart';
import '../models/printer_settings.dart';
import '../core/database_helper.dart';
import '../core/printing_service.dart';

class PrinterProvider with ChangeNotifier {
  List<PrinterSettings> _printers = [];
  List<String> _windowsPrinters = [];
  List<String> _legacyUsbPrinters = []; // For fallback
  bool _isLoading = false;

  List<PrinterSettings> get printers => _printers;
  // Keeps compatibility with old code that expects single settings
  PrinterSettings get settings =>
      _printers.isNotEmpty ? _printers.first : PrinterSettings();
  List<String> get windowsPrinters => _windowsPrinters;
  List<String> get legacyUsbPrinters => _legacyUsbPrinters;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('printers');

    if (res.isNotEmpty) {
      _printers = res.map((m) => PrinterSettings.fromMap(m)).toList();
    } else {
      // Fallback/Migration: check old settings table
      final oldRes = await db.query('settings');
      if (oldRes.isNotEmpty) {
        Map<String, dynamic> settingsMap = {};
        for (var row in oldRes) {
          settingsMap[row['key'] as String] = row['value'];
        }
        if (settingsMap.containsKey('printer_type')) {
          final oldSettings = PrinterSettings.fromMap(
            settingsMap,
          ).copyWith(displayName: 'Asosiy Printer');
          _printers = [oldSettings];
          // Proactively save to new table
          await savePrinter(oldSettings);
        }
      }
    }
    notifyListeners();
  }

  Future<void> savePrinter(PrinterSettings printer) async {
    final db = await DatabaseHelper.instance.database;
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
    await loadSettings();
  }

  Future<void> deletePrinter(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('printers', where: 'id = ?', whereArgs: [id]);
    await loadSettings();
  }

  Future<void> saveSettings(PrinterSettings newSettings) async {
    // For compatibility with old single-printer code
    if (_printers.isEmpty) {
      await savePrinter(newSettings);
    } else {
      await savePrinter(newSettings.copyWith(id: _printers.first.id));
    }
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
    return await PrintingService.testPrint(
      settings: settings ?? (this.settings),
    );
  }
}

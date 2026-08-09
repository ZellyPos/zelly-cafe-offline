import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/printer_repository.dart';
import '../models/printer_settings.dart';
import '../core/printing_service.dart';

const String _kSelectedReceiptPrinterId = 'selected_receipt_printer_id';

class PrinterProvider with ChangeNotifier {
  final PrinterRepository _repo;

  PrinterProvider({PrinterRepository? repository})
    : _repo = repository ?? PrinterRepository();

  List<PrinterSettings> _printers = [];
  List<String> _windowsPrinters = [];
  List<String> _legacyUsbPrinters = []; // For fallback
  bool _isLoading = false;
  int? _selectedReceiptPrinterId; // Per-device selection

  List<PrinterSettings> get printers => _printers;
  int? get selectedReceiptPrinterId => _selectedReceiptPrinterId;

  /// Returns the receipt printer selected for THIS device.
  /// Falls back to the first printer if none selected.
  PrinterSettings get settings {
    if (_selectedReceiptPrinterId != null) {
      final found = _printers.where((p) => p.id == _selectedReceiptPrinterId);
      if (found.isNotEmpty) return found.first;
    }
    return _printers.isNotEmpty ? _printers.first : PrinterSettings();
  }

  List<String> get windowsPrinters => _windowsPrinters;
  List<String> get legacyUsbPrinters => _legacyUsbPrinters;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedReceiptPrinterId = prefs.getInt(_kSelectedReceiptPrinterId);

    _printers = await _repo.getPrinters();

    if (_printers.isEmpty) {
      // Fallback/Migration: check old settings table
      final settingsMap = await _repo.getLegacySettings();
      if (settingsMap.containsKey('printer_type')) {
        final oldSettings = PrinterSettings.fromMap(
          settingsMap,
        ).copyWith(displayName: 'Asosiy Printer');
        // Proactively save to new table, then reload to pick up the assigned id
        await _repo.savePrinter(oldSettings);
        _printers = await _repo.getPrinters();
      }
    }
    notifyListeners();
  }

  Future<void> savePrinter(PrinterSettings printer) async {
    await _repo.savePrinter(printer);
    await loadSettings();
  }

  Future<void> deletePrinter(int id) async {
    await _repo.deletePrinter(id);
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

  /// Saves the receipt printer selection locally for THIS device only.
  Future<void> setSelectedReceiptPrinter(int? printerId) async {
    _selectedReceiptPrinterId = printerId;
    final prefs = await SharedPreferences.getInstance();
    if (printerId == null) {
      await prefs.remove(_kSelectedReceiptPrinterId);
    } else {
      await prefs.setInt(_kSelectedReceiptPrinterId, printerId);
    }
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
    return await PrintingService.testPrint(
      settings: settings ?? (this.settings),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../data/repositories/settings_repository.dart';
import '../models/receipt_settings.dart';

class ReceiptSettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;

  ReceiptSettingsProvider({SettingsRepository? repository})
    : _repo = repository ?? SettingsRepository() {
    loadSettings();
  }

  ReceiptSettings _settings = ReceiptSettings();

  ReceiptSettings get settings => _settings;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbMap = await _repo.getAll();
      if (dbMap.isNotEmpty) {
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
    await _repo.saveAll(newSettings.toMap());
  }
}

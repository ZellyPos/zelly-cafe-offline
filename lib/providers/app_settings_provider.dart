import 'package:flutter/material.dart';
import '../data/repositories/settings_repository.dart';
import '../core/services/telegram_bot_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;

  AppSettingsProvider({SettingsRepository? repository})
    : _repo = repository ?? SettingsRepository();

  String _loginPin = '0000';
  String? _brandImagePath;
  String _restaurantName = 'ZELLY';
  String? _telegramBotToken;
  String? _telegramChatId;
  ThemeMode _themeMode = ThemeMode.light;
  bool _autoConfirmOrder = false;
  bool _enableInventory = false;

  String get loginPin => _loginPin;
  String? get brandImagePath => _brandImagePath;
  String get restaurantName => _restaurantName;
  String? get telegramBotToken => _telegramBotToken;
  String? get telegramChatId => _telegramChatId;
  ThemeMode get themeMode => _themeMode;
  bool get autoConfirmOrder => _autoConfirmOrder;
  bool get enableInventory => _enableInventory;

  Future<void> loadSettings() async {
    // Barcha sozlamalarni bitta query da olamiz
    final settings = await _repo.getAll();

    _loginPin = settings['login_pin'] ?? '0000';
    if (!settings.containsKey('login_pin')) {
      await _repo.setValue('login_pin', '0000');
    }

    _brandImagePath = settings['login_brand_image_path'];
    _restaurantName = settings['restaurant_name'] ?? 'ZELLY';
    _telegramBotToken = settings['telegram_bot_token'];
    _telegramChatId = settings['telegram_chat_id'];

    final themeVal = settings['theme_mode'];
    if (themeVal != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeVal,
        orElse: () => ThemeMode.light,
      );
    }

    _autoConfirmOrder = settings['auto_confirm_order'] == 'true';
    _enableInventory = settings['enable_inventory'] == 'true';

    _startBot();
    notifyListeners();
  }

  void _startBot({bool stopIfEmpty = false}) {
    final token = _telegramBotToken;
    if (token != null && token.isNotEmpty) {
      TelegramBotService.instance.start(
        token: token,
        restaurantName: _restaurantName,
        allowedChatId: _telegramChatId,
      );
    } else if (stopIfEmpty) {
      TelegramBotService.instance.stop();
    }
  }

  Future<void> setAutoConfirmOrder(bool value) async {
    await _repo.setValue('auto_confirm_order', value.toString());
    _autoConfirmOrder = value;
    notifyListeners();
  }

  Future<void> setEnableInventory(bool value) async {
    await _repo.setValue('enable_inventory', value.toString());
    _enableInventory = value;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.setValue('theme_mode', mode.name);
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setTelegramSettings(String? token, String? chatId) async {
    if (token != null && token.isNotEmpty) {
      await _repo.setValue('telegram_bot_token', token);
      _telegramBotToken = token;
    }

    if (chatId != null && chatId.isNotEmpty) {
      await _repo.setValue('telegram_chat_id', chatId);
      _telegramChatId = chatId;
    }

    _startBot(stopIfEmpty: true);
    notifyListeners();
  }

  Future<void> setRestaurantName(String name) async {
    await _repo.setValue('restaurant_name', name);
    _restaurantName = name;
    TelegramBotService.instance.updateRestaurantName(name);
    notifyListeners();
  }

  Future<bool> updatePin(String currentPin, String newPin) async {
    if (currentPin != _loginPin) return false;

    await _repo.updateValue('login_pin', newPin);
    _loginPin = newPin;
    notifyListeners();
    return true;
  }

  Future<void> setBrandImage(String filePath) async {
    final appDir = await getApplicationSupportDirectory();
    final fileName = 'brand_image${p.extension(filePath)}';
    final savedPath = p.join(appDir.path, fileName);

    // Copy file to app directory
    final file = File(filePath);
    await file.copy(savedPath);

    await _repo.setValue('login_brand_image_path', savedPath);
    _brandImagePath = savedPath;
    notifyListeners();
  }

  Future<void> removeBrandImage() async {
    if (_brandImagePath != null) {
      final file = File(_brandImagePath!);
      if (await file.exists()) {
        await file.delete();
      }

      await _repo.deleteKey('login_brand_image_path');
      _brandImagePath = null;
      notifyListeners();
    }
  }
}

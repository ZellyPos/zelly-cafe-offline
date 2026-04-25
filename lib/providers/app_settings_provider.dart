import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../core/services/telegram_bot_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettingsProvider extends ChangeNotifier {
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
    final db = DatabaseHelper.instance;

    final pinRes = await db.queryByColumn('settings', 'key', 'login_pin');
    if (pinRes.isNotEmpty) {
      _loginPin = pinRes.first['value'];
    } else {
      await db.insert('settings', {'key': 'login_pin', 'value': '0000'});
      _loginPin = '0000';
    }

    final imageRes = await db.queryByColumn(
      'settings',
      'key',
      'login_brand_image_path',
    );
    if (imageRes.isNotEmpty) {
      _brandImagePath = imageRes.first['value'];
    }

    final nameRes = await db.queryByColumn(
      'settings',
      'key',
      'restaurant_name',
    );
    if (nameRes.isNotEmpty) {
      _restaurantName = nameRes.first['value'];
    }

    final tokenRes = await db.queryByColumn(
      'settings',
      'key',
      'telegram_bot_token',
    );
    if (tokenRes.isNotEmpty) {
      _telegramBotToken = tokenRes.first['value'];
    }

    final chatRes = await db.queryByColumn(
      'settings',
      'key',
      'telegram_chat_id',
    );
    if (chatRes.isNotEmpty) {
      _telegramChatId = chatRes.first['value'];
    }

    final themeRes = await db.queryByColumn('settings', 'key', 'theme_mode');
    if (themeRes.isNotEmpty) {
      final value = themeRes.first['value'];
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ThemeMode.light,
      );
    }

    final autoConfirmRes = await db.queryByColumn(
      'settings',
      'key',
      'auto_confirm_order',
    );
    if (autoConfirmRes.isNotEmpty) {
      _autoConfirmOrder = autoConfirmRes.first['value'] == 'true';
    }

    final inventoryRes = await db.queryByColumn(
      'settings',
      'key',
      'enable_inventory',
    );
    if (inventoryRes.isNotEmpty) {
      _enableInventory = inventoryRes.first['value'] == 'true';
    }

    _startBot();
    notifyListeners();
  }

  void _startBot() {
    final token = _telegramBotToken;
    if (token != null && token.isNotEmpty) {
      TelegramBotService.instance.start(
        token: token,
        restaurantName: _restaurantName,
      );
    } else {
      TelegramBotService.instance.stop();
    }
  }

  Future<void> setAutoConfirmOrder(bool value) async {
    final db = DatabaseHelper.instance;
    final existing = await db.queryByColumn(
      'settings',
      'key',
      'auto_confirm_order',
    );
    if (existing.isNotEmpty) {
      await db.update(
        'settings',
        {'value': value.toString()},
        'key = ?',
        ['auto_confirm_order'],
      );
    } else {
      await db.insert('settings', {
        'key': 'auto_confirm_order',
        'value': value.toString(),
      });
    }
    _autoConfirmOrder = value;
    notifyListeners();
  }

  Future<void> setEnableInventory(bool value) async {
    final db = DatabaseHelper.instance;
    final existing = await db.queryByColumn(
      'settings',
      'key',
      'enable_inventory',
    );
    if (existing.isNotEmpty) {
      await db.update(
        'settings',
        {'value': value.toString()},
        'key = ?',
        ['enable_inventory'],
      );
    } else {
      await db.insert('settings', {
        'key': 'enable_inventory',
        'value': value.toString(),
      });
    }
    _enableInventory = value;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final db = DatabaseHelper.instance;
    final existing = await db.queryByColumn('settings', 'key', 'theme_mode');
    if (existing.isNotEmpty) {
      await db.update(
        'settings',
        {'value': mode.name},
        'key = ?',
        ['theme_mode'],
      );
    } else {
      await db.insert('settings', {'key': 'theme_mode', 'value': mode.name});
    }
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setTelegramSettings(String? token, String? chatId) async {
    final db = DatabaseHelper.instance;

    if (token != null && token.isNotEmpty) {
      final existing = await db.queryByColumn(
        'settings',
        'key',
        'telegram_bot_token',
      );
      if (existing.isNotEmpty) {
        await db.update(
          'settings',
          {'value': token},
          'key = ?',
          ['telegram_bot_token'],
        );
      } else {
        await db.insert('settings', {
          'key': 'telegram_bot_token',
          'value': token,
        });
      }
      _telegramBotToken = token;
    }

    if (chatId != null && chatId.isNotEmpty) {
      final existing = await db.queryByColumn(
        'settings',
        'key',
        'telegram_chat_id',
      );
      if (existing.isNotEmpty) {
        await db.update(
          'settings',
          {'value': chatId},
          'key = ?',
          ['telegram_chat_id'],
        );
      } else {
        await db.insert('settings', {
          'key': 'telegram_chat_id',
          'value': chatId,
        });
      }
      _telegramChatId = chatId;
    }

    _startBot();
    notifyListeners();
  }

  Future<void> setRestaurantName(String name) async {
    final db = DatabaseHelper.instance;
    final existing = await db.queryByColumn(
      'settings',
      'key',
      'restaurant_name',
    );
    if (existing.isNotEmpty) {
      await db.update(
        'settings',
        {'value': name},
        'key = ?',
        ['restaurant_name'],
      );
    } else {
      await db.insert('settings', {'key': 'restaurant_name', 'value': name});
    }
    _restaurantName = name;
    TelegramBotService.instance.updateRestaurantName(name);
    notifyListeners();
  }

  Future<bool> updatePin(String currentPin, String newPin) async {
    if (currentPin != _loginPin) return false;

    final db = DatabaseHelper.instance;
    await db.update('settings', {'value': newPin}, 'key = ?', ['login_pin']);
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

    final db = DatabaseHelper.instance;
    final existing = await db.queryByColumn(
      'settings',
      'key',
      'login_brand_image_path',
    );

    if (existing.isNotEmpty) {
      await db.update(
        'settings',
        {'value': savedPath},
        'key = ?',
        ['login_brand_image_path'],
      );
    } else {
      await db.insert('settings', {
        'key': 'login_brand_image_path',
        'value': savedPath,
      });
    }

    _brandImagePath = savedPath;
    notifyListeners();
  }

  Future<void> removeBrandImage() async {
    if (_brandImagePath != null) {
      final file = File(_brandImagePath!);
      if (await file.exists()) {
        await file.delete();
      }

      final db = DatabaseHelper.instance;
      await db.delete('settings', 'key = ?', ['login_brand_image_path']);
      _brandImagePath = null;
      notifyListeners();
    }
  }
}

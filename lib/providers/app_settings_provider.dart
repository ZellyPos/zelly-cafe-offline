import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettingsProvider extends ChangeNotifier {
  String _loginPin = '0000';
  String? _brandImagePath;
  String _restaurantName = 'ZELLY';
  String? _telegramBotToken;
  String? _telegramChatId;

  String get loginPin => _loginPin;
  String? get brandImagePath => _brandImagePath;
  String get restaurantName => _restaurantName;
  String? get telegramBotToken => _telegramBotToken;
  String? get telegramChatId => _telegramChatId;

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

    notifyListeners();
  }

  Future<void> setTelegramSettings(String? token, String? chatId) async {
    final db = DatabaseHelper.instance;

    if (token != null) {
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

    if (chatId != null) {
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

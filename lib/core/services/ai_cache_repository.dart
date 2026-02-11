import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/ai_cache_entry.dart';

class AiCacheRepository {
  Future<String?> get(String prompt, Map<String, dynamic> filters) async {
    final key = _generateKey(prompt, filters);
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'ai_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (res.isNotEmpty) {
      final entry = AiCacheEntry.fromMap(res.first);
      // Auto-expire after 24 hours
      if (DateTime.now().difference(entry.createdAt).inHours < 24) {
        return entry.response;
      } else {
        await delete(key);
      }
    }
    return null;
  }

  Future<void> save(
    String prompt,
    Map<String, dynamic> filters,
    String response,
  ) async {
    final key = _generateKey(prompt, filters);
    final db = await DatabaseHelper.instance.database;
    final entry = AiCacheEntry(
      cacheKey: key,
      response: response,
      createdAt: DateTime.now(),
    );
    await db.insert(
      'ai_cache',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String key) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('ai_cache', where: 'cache_key = ?', whereArgs: [key]);
  }

  String _generateKey(String prompt, Map<String, dynamic> filters) {
    final combined = '$prompt${jsonEncode(filters)}';
    return sha256.convert(utf8.encode(combined)).toString();
  }
}

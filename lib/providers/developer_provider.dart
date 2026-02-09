import 'package:flutter/material.dart';
import '../core/database_helper.dart';

class DeveloperProvider with ChangeNotifier {
  List<String> _tables = [];
  List<String> get tables => _tables;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadTables() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'",
      );

      _tables = result.map((row) => row['name'] as String).toList();
      _tables.sort();
    } catch (e) {
      debugPrint('Error loading tables: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getTableData(String tableName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.query(tableName);
    } catch (e) {
      debugPrint('Error loading table data for $tableName: $e');
      return [];
    }
  }

  Future<bool> deleteRow(String tableName, String idColumn, dynamic id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(tableName, where: '$idColumn = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('Error deleting row from $tableName: $e');
      return false;
    }
  }

  Future<bool> updateRow(
    String tableName,
    String idColumn,
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(tableName, data, where: '$idColumn = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('Error updating row in $tableName: $e');
      return false;
    }
  }

  Future<bool> addRow(String tableName, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(tableName, data);
      return true;
    } catch (e) {
      debugPrint('Error adding row to $tableName: $e');
      return false;
    }
  }

  Future<void> executeRawQuery(String query) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute(query);
    } catch (e) {
      debugPrint('Error executing raw query: $e');
      rethrow;
    }
  }
}

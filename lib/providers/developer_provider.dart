import 'package:flutter/material.dart';
import '../data/repositories/developer_repository.dart';

class DeveloperProvider with ChangeNotifier {
  final DeveloperRepository _repo;

  DeveloperProvider({DeveloperRepository? repository})
    : _repo = repository ?? DeveloperRepository();

  List<String> _tables = [];
  List<String> get tables => _tables;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadTables() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tables = await _repo.getTableNames();
    } catch (e) {
      debugPrint('Error loading tables: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getTableData(String tableName) async {
    try {
      return await _repo.getTableData(tableName);
    } catch (e) {
      debugPrint('Error loading table data for $tableName: $e');
      return [];
    }
  }

  Future<bool> deleteRow(String tableName, String idColumn, dynamic id) async {
    try {
      await _repo.deleteRow(tableName, idColumn, id);
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
      await _repo.updateRow(tableName, idColumn, id, data);
      return true;
    } catch (e) {
      debugPrint('Error updating row in $tableName: $e');
      return false;
    }
  }

  Future<bool> addRow(String tableName, Map<String, dynamic> data) async {
    try {
      await _repo.addRow(tableName, data);
      return true;
    } catch (e) {
      debugPrint('Error adding row to $tableName: $e');
      return false;
    }
  }

  Future<void> executeRawQuery(String query) async {
    try {
      await _repo.executeRawQuery(query);
    } catch (e) {
      debugPrint('Error executing raw query: $e');
      rethrow;
    }
  }
}

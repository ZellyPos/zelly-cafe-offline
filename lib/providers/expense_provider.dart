import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/expense_category.dart';
import '../models/expense.dart';
import 'connectivity_provider.dart';

class ExpenseProvider extends ChangeNotifier {
  List<ExpenseCategory> _categories = [];
  List<Expense> _expenses = [];
  bool _isLoading = false;

  List<ExpenseCategory> get categories => _categories;
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  Future<void> loadCategories({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData(
          '/expense_categories',
        );
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        data = await DatabaseHelper.instance.queryAll('expense_categories');
      }
      _categories = data.map((e) => ExpenseCategory.fromMap(e)).toList();
    } catch (e) {
      debugPrint("Error loading expense categories: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(
    String name, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/expense_categories', {'name': name});
    } else {
      await DatabaseHelper.instance.insert('expense_categories', {
        'name': name,
      });
    }
    await loadCategories(connectivity: connectivity);
  }

  Future<void> updateCategory(
    int id,
    String name, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/expense_categories', {
        'id': id,
        'name': name,
      });
    } else {
      await DatabaseHelper.instance.update(
        'expense_categories',
        {'name': name},
        'id = ?',
        [id],
      );
    }
    await loadCategories(connectivity: connectivity);
  }

  Future<void> deleteCategory(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/expense_categories/$id');
    } else {
      await DatabaseHelper.instance.delete('expense_categories', 'id = ?', [
        id,
      ]);
    }
    await loadCategories(connectivity: connectivity);
  }

  Future<void> loadExpenses({
    DateTime? start,
    DateTime? end,
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> results;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData('/expenses');
        // Simple filtering on client side for now if needed, or let server handle it
        // For simplicity, we fetch all and if dates present, we can filter here
        results = List<Map<String, dynamic>>.from(remoteData);
      } else {
        final db = await DatabaseHelper.instance.database;
        String where = '';
        List<dynamic> whereArgs = [];

        if (start != null && end != null) {
          where = 'date(created_at) BETWEEN date(?) AND date(?)';
          whereArgs = [
            start.toIso8601String().split('T')[0],
            end.toIso8601String().split('T')[0],
          ];
        }

        results = await db.query(
          'expenses',
          where: where.isEmpty ? null : where,
          whereArgs: whereArgs.isEmpty ? null : whereArgs,
          orderBy: 'created_at DESC',
        );
      }

      // Filter by date on client side if remote
      var filteredResults = results;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote) &&
          start != null &&
          end != null) {
        final startDate = DateTime(start.year, start.month, start.day);
        final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
        filteredResults = results.where((item) {
          final createdAt = DateTime.parse(item['created_at'] as String);
          return createdAt.isAfter(startDate) && createdAt.isBefore(endDate);
        }).toList();
      }

      _expenses = filteredResults.map((e) => Expense.fromMap(e)).toList();
    } catch (e) {
      debugPrint("Error loading expenses: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(
    Expense expense, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/expenses', expense.toMap());
    } else {
      await DatabaseHelper.instance.insert('expenses', expense.toMap());
    }
    await loadExpenses(connectivity: connectivity);
  }

  Future<void> deleteExpense(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/expenses/$id');
    } else {
      await DatabaseHelper.instance.delete('expenses', 'id = ?', [id]);
    }
    await loadExpenses(connectivity: connectivity);
  }
}

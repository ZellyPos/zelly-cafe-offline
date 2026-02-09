import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/expense_category.dart';
import '../models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  List<ExpenseCategory> _categories = [];
  List<Expense> _expenses = [];
  bool _isLoading = false;

  List<ExpenseCategory> get categories => _categories;
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    final db = DatabaseHelper.instance;
    final results = await db.queryAll('expense_categories');
    _categories = results.map((e) => ExpenseCategory.fromMap(e)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    final db = DatabaseHelper.instance;
    await db.insert('expense_categories', {'name': name});
    await loadCategories();
  }

  Future<void> updateCategory(int id, String name) async {
    final db = DatabaseHelper.instance;
    await db.update('expense_categories', {'name': name}, 'id = ?', [id]);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    final db = DatabaseHelper.instance;
    await db.delete('expense_categories', 'id = ?', [id]);
    await loadCategories();
  }

  Future<void> loadExpenses({DateTime? start, DateTime? end}) async {
    _isLoading = true;
    notifyListeners();

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

    final results = await db.query(
      'expenses',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
    _expenses = results.map((e) => Expense.fromMap(e)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    final db = DatabaseHelper.instance;
    await db.insert('expenses', expense.toMap());
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    final db = DatabaseHelper.instance;
    await db.delete('expenses', 'id = ?', [id]);
    await loadExpenses();
  }
}

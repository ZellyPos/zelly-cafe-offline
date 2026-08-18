import 'package:flutter/material.dart';
import '../data/repositories/expense_repository.dart';
import '../models/expense_category.dart';
import '../models/expense.dart';
import 'connectivity_provider.dart';

enum ExpenseFilter { today, currentShift, all }

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _repo;

  ExpenseProvider({ExpenseRepository? repository})
    : _repo = repository ?? ExpenseRepository();

  List<ExpenseCategory> _categories = [];
  List<Expense> _expenses = [];
  Map<String, double> _categoryTotals = {};
  bool _isLoading = false;
  ExpenseFilter _filter = ExpenseFilter.today;
  int? _currentShiftId;

  List<ExpenseCategory> get categories => _categories;
  List<Expense> get expenses => _expenses;
  Map<String, double> get categoryTotals => _categoryTotals;
  bool get isLoading => _isLoading;
  ExpenseFilter get filter => _filter;
  int? get currentShiftId => _currentShiftId;

  double get totalAmount =>
      _expenses.fold(0, (sum, e) => sum + e.amount);

  Future<void> loadCategories({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _categories = await _repo.getCategories(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint('Error loading expense categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(String name, {ConnectivityProvider? connectivity}) async {
    await _repo.addCategory(name, connectivity: connectivity);
    await loadCategories(connectivity: connectivity);
  }

  Future<void> updateCategory(int id, String name, {ConnectivityProvider? connectivity}) async {
    await _repo.updateCategory(id, name, connectivity: connectivity);
    await loadCategories(connectivity: connectivity);
  }

  Future<void> deleteCategory(int id, {ConnectivityProvider? connectivity}) async {
    await _repo.deleteCategory(id, connectivity: connectivity);
    await loadCategories(connectivity: connectivity);
  }

  // Filtr o'rnatish va qayta yuklash
  Future<void> setFilter(ExpenseFilter filter, {int? shiftId}) async {
    _filter = filter;
    if (shiftId != null) _currentShiftId = shiftId;
    await _loadByFilter();
  }

  Future<void> loadExpenses({
    DateTime? start,
    DateTime? end,
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
    int? shiftId,
  }) async {
    if (shiftId != null) _currentShiftId = shiftId;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadByFilter();
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadByFilter() async {
    _isLoading = true;
    notifyListeners();
    try {
      List<Expense> rows;
      Map<String, double> totals;

      switch (_filter) {
        case ExpenseFilter.today:
          rows = await _repo.getTodayExpenses();
          final today = DateTime.now();
          final start = DateTime(today.year, today.month, today.day).toIso8601String();
          final end = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
          totals = await _repo.getExpenseTotalsByCategory(start: start, end: end);
          break;
        case ExpenseFilter.currentShift:
          if (_currentShiftId != null) {
            rows = await _repo.getExpensesByShift(_currentShiftId!);
            totals = await _repo.getExpenseTotalsByCategory(shiftId: _currentShiftId);
          } else {
            rows = await _repo.getTodayExpenses();
            totals = await _repo.getExpenseTotalsByCategory();
          }
          break;
        case ExpenseFilter.all:
          rows = await _repo.getAllExpenses();
          totals = await _repo.getExpenseTotalsByCategory();
          break;
      }

      _expenses = rows;
      _categoryTotals = totals;
    } catch (e) {
      debugPrint('Error in _loadByFilter: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(
    Expense expense, {
    ConnectivityProvider? connectivity,
    int? shiftId,
  }) async {
    final expenseWithShift = Expense(
      id: expense.id,
      categoryId: expense.categoryId,
      amount: expense.amount,
      note: expense.note,
      createdAt: expense.createdAt,
      shiftId: shiftId ?? expense.shiftId ?? _currentShiftId,
    );

    await _repo.addExpense(expenseWithShift, connectivity: connectivity);
    await _loadByFilter();
  }

  Future<void> deleteExpense(int id, {ConnectivityProvider? connectivity}) async {
    await _repo.deleteExpense(id, connectivity: connectivity);
    await _loadByFilter();
  }
}

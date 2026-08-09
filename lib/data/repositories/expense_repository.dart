import '../../core/database_helper.dart';
import '../../models/expense.dart';
import '../../models/expense_category.dart';
import '../../providers/connectivity_provider.dart';

/// Xarajatlar va xarajat kategoriyalari uchun ma'lumotlar qatlami.
class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Kategoriyalar ---

  Future<List<ExpenseCategory>> getCategories({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    final List<Map<String, dynamic>> data;
    if (connectivity != null &&
        connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
      final remoteData = await connectivity.getRemoteData('/expense_categories');
      data = List<Map<String, dynamic>>.from(remoteData);
    } else {
      data = await _dbHelper.queryAll('expense_categories');
    }
    return data.map((e) => ExpenseCategory.fromMap(e)).toList();
  }

  Future<void> addCategory(
    String name, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/expense_categories', {'name': name});
    } else {
      await _dbHelper.insertExpenseCategory(name);
    }
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
      await _dbHelper.update('expense_categories', {'name': name}, 'id = ?', [id]);
    }
  }

  Future<void> deleteCategory(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/expense_categories/$id');
    } else {
      await _dbHelper.delete('expense_categories', 'id = ?', [id]);
    }
  }

  // --- Xarajatlar ---

  Future<List<Expense>> getTodayExpenses() async {
    final rows = await _dbHelper.getTodayExpenses();
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<List<Expense>> getExpensesByShift(int shiftId) async {
    final rows = await _dbHelper.getExpensesByShift(shiftId);
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final rows = await _dbHelper.getAllExpenses();
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<Map<String, double>> getExpenseTotalsByCategory({
    String? start,
    String? end,
    int? shiftId,
  }) {
    return _dbHelper.getExpenseTotalsByCategory(
      start: start,
      end: end,
      shiftId: shiftId,
    );
  }

  Future<void> addExpense(
    Expense expense, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/expenses', expense.toMap());
    } else {
      await _dbHelper.insert('expenses', expense.toMap());
    }
  }

  Future<void> deleteExpense(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/expenses/$id');
    } else {
      await _dbHelper.delete('expenses', 'id = ?', [id]);
    }
  }
}

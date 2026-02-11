import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/category.dart';
import 'connectivity_provider.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
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
        final remoteData = await connectivity.getRemoteData('/categories');
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        final db = await DatabaseHelper.instance.database;
        data = await db.query('categories', orderBy: 'sort_order ASC');
      }
      _categories = data.map((item) => Category.fromMap(item)).toList();
    } catch (e) {
      debugPrint("Error loading categories: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reorderCategories(
    int oldIndex,
    int newIndex, {
    ConnectivityProvider? connectivity,
  }) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Category category = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, category);

    // Update all indices
    for (int i = 0; i < _categories.length; i++) {
      final updatedCat = _categories[i].copyWith(sortOrder: i);
      _categories[i] = updatedCat;

      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        await connectivity.postRemoteData('/categories', updatedCat.toMap());
      } else {
        await DatabaseHelper.instance.update(
          'categories',
          updatedCat.toMap(),
          'id = ?',
          [updatedCat.id],
        );
      }
    }
    notifyListeners();
  }

  Future<void> addCategory(
    Category category, {
    ConnectivityProvider? connectivity,
  }) async {
    // Add to the end
    final newCategory = category.copyWith(sortOrder: _categories.length);

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/categories', newCategory.toMap());
    } else {
      await DatabaseHelper.instance.insert('categories', newCategory.toMap());
    }
    await loadCategories(connectivity: connectivity);
  }

  Future<void> updateCategory(
    Category category, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/categories', category.toMap());
    } else {
      await DatabaseHelper.instance.update(
        'categories',
        category.toMap(),
        'id = ?',
        [category.id],
      );
    }
    await loadCategories(connectivity: connectivity);
  }

  Future<void> deleteCategory(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/categories/$id');
    } else {
      await DatabaseHelper.instance.delete('categories', 'id = ?', [id]);
    }
    await loadCategories(connectivity: connectivity);
  }
}

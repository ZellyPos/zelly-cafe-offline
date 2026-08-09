import 'package:flutter/material.dart';
import '../data/repositories/category_repository.dart';
import '../models/category.dart';
import 'connectivity_provider.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repo;

  CategoryProvider({CategoryRepository? repository})
    : _repo = repository ?? CategoryRepository();

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
      _categories = await _repo.getAll(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
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

    // Barcha indekslarni yangilash
    for (int i = 0; i < _categories.length; i++) {
      final updatedCat = _categories[i].copyWith(sortOrder: i);
      _categories[i] = updatedCat;
      await _repo.update(updatedCat, connectivity: connectivity);
    }
    notifyListeners();
  }

  Future<void> addCategory(
    Category category, {
    ConnectivityProvider? connectivity,
  }) async {
    // Ro'yxat oxiriga qo'shiladi
    final newCategory = category.copyWith(sortOrder: _categories.length);
    await _repo.add(newCategory, connectivity: connectivity);
    await loadCategories(connectivity: connectivity);
  }

  Future<void> updateCategory(
    Category category, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.update(category, connectivity: connectivity);
    await loadCategories(connectivity: connectivity);
  }

  Future<void> deleteCategory(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.deleteById(id, connectivity: connectivity);
    await loadCategories(connectivity: connectivity);
  }
}

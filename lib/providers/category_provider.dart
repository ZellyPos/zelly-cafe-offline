import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/category.dart';
import 'connectivity_provider.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories([ConnectivityProvider? connectivity]) async {
    _isLoading = true;
    notifyListeners();

    final List<Map<String, dynamic>> data;
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final remoteData = await connectivity.getRemoteData('/categories');
      data = List<Map<String, dynamic>>.from(remoteData);
    } else {
      data = await DatabaseHelper.instance.queryAll('categories');
    }
    _categories = data.map((item) => Category.fromMap(item)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    await DatabaseHelper.instance.insert('categories', category.toMap());
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await DatabaseHelper.instance.update(
      'categories',
      category.toMap(),
      'id = ?',
      [category.id],
    );
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await DatabaseHelper.instance.delete('categories', 'id = ?', [id]);
    await loadCategories();
  }
}

import 'package:flutter/material.dart';
import '../core/services/inventory_service.dart';
import '../models/inventory_models.dart';
import '../repositories/inventory_repository.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryService _service = InventoryService.instance;
  final InventoryRepository _repo = InventoryRepository();

  List<Ingredient> _ingredients = [];
  List<Ingredient> get ingredients => _ingredients;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadIngredients() async {
    _isLoading = true;
    notifyListeners();
    try {
      _ingredients = await _repo.getAllIngredients();
    } catch (e) {
      debugPrint('Load ingredients error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<IngredientStock?> getStock(int ingredientId) async {
    return await _repo.getIngredientStock(ingredientId);
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    await _repo.insertIngredient(ingredient);
    await loadIngredients();
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    await _repo.updateIngredient(ingredient);
    await loadIngredients();
  }

  Future<void> deleteIngredient(int id) async {
    await _repo.deleteIngredient(id);
    await loadIngredients();
  }

  Future<void> purchaseStock({
    required int ingredientId,
    required double qty,
    String? note,
  }) async {
    await _service.purchaseIn(ingredientId: ingredientId, qty: qty, note: note);
    notifyListeners();
  }

  Future<void> wasteStock({
    required int ingredientId,
    required double qty,
    String? reason,
  }) async {
    await _service.wasteOut(
      ingredientId: ingredientId,
      qty: qty,
      reason: reason,
    );
    notifyListeners();
  }

  Future<void> adjustStock({
    required int ingredientId,
    required double realQty,
    String? note,
  }) async {
    await _service.adjustStock(
      ingredientId: ingredientId,
      realQty: realQty,
      note: note,
    );
    notifyListeners();
  }

  Future<void> saveRecipe(Recipe recipe) async {
    await _repo.upsertRecipe(recipe);
    notifyListeners();
  }

  Future<Recipe?> getRecipe(int productId) async {
    return await _repo.getRecipeForProduct(productId);
  }

  Future<List<Map<String, dynamic>>> getMovements() async {
    return await _repo.getStockMovements();
  }
}

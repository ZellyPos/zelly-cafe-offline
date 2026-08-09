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

  // --- Ombor moduli (yangi) ---

  /// Pishirish: retsept bo'yicha xomashyo chegiriladi + tayyor son oshadi.
  ///
  /// Xomashyo yetmasa [InsufficientStockException] tashlaydi (agar
  /// [allowNegative] `false` bo'lsa).
  Future<void> produce(
    List<({int productId, double count})> items, {
    int? userId,
    bool allowNegative = false,
  }) async {
    await _service.produce(items, userId: userId, allowNegative: allowNegative);
    await loadIngredients();
  }

  /// Xomashyo kirimi (tannarx + yetkazuvchi).
  Future<void> stockIn({
    required int ingredientId,
    required double qty,
    double cost = 0,
    String? supplier,
  }) async {
    await _repo.stockIn(
      ingredientId: ingredientId,
      qty: qty,
      cost: cost,
      supplier: supplier,
    );
    await loadIngredients();
  }

  /// Xomashyo chiqimi.
  Future<void> stockOut({
    required int ingredientId,
    required double qty,
    String reason = 'waste',
    String? note,
  }) async {
    await _repo.stockOut(
      ingredientId: ingredientId,
      qty: qty,
      reason: reason,
      note: note,
    );
    await loadIngredients();
  }

  /// Resale mahsulot kirimi.
  Future<void> resaleStockIn({
    required int productId,
    required double qty,
    double cost = 0,
    String? supplier,
  }) async {
    await _repo.resaleStockIn(
      productId: productId,
      qty: qty,
      cost: cost,
      supplier: supplier,
    );
    notifyListeners();
  }

  /// Tayyor mahsulot chiqimi (waste).
  Future<void> productWaste({
    required int productId,
    required double qty,
    String? note,
  }) async {
    await _repo.productWaste(productId: productId, qty: qty, note: note);
    notifyListeners();
  }

  /// Ko'p qatorli kirim/chiqim — bitta tranzaksiyada (§4.5).
  Future<void> applyStockBatch(
    List<StockBatchLine> lines, {
    int? userId,
  }) async {
    await _repo.applyStockBatch(lines, userId: userId);
    await loadIngredients();
  }

  /// Inventarizatsiya — xomashyolarni real songa tenglashtirish.
  Future<void> reconcileIngredients(Map<int, double> realCounts) async {
    await _repo.reconcileIngredients(realCounts);
    await loadIngredients();
  }

  /// Inventarizatsiya — tayyor mahsulotlarni real songa tenglashtirish.
  Future<void> reconcileProducts(Map<int, double> realCounts) async {
    await _repo.reconcileProducts(realCounts);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getIngredientsWithStock() =>
      _repo.getIngredientsWithStock();

  Future<List<Map<String, dynamic>>> getPreparedProducts() =>
      _repo.getPreparedProducts();

  Future<List<Map<String, dynamic>>> getResaleProducts() =>
      _repo.getResaleProducts();

  Future<List<Map<String, dynamic>>> getProductMovements({int? productId}) =>
      _repo.getProductMovements(productId: productId);

  /// Retsept tannarxi (food-cost uchun). Retsepti yo'q bo'lsa `null`.
  Future<double?> recipeCost(int productId) => _repo.recipeCost(productId);

  /// Bir nechta mahsulotning retsept tannarxi — bitta so'rovda.
  Future<Map<int, double>> getRecipeCosts({List<int>? productIds}) =>
      _repo.getRecipeCosts(productIds: productIds);

  /// Birlashgan tarix (xomashyo + tayyor mahsulot), filtrlar bilan.
  Future<List<Map<String, dynamic>>> getHistory({
    DateTime? from,
    DateTime? to,
    List<String>? types,
    int? itemId,
    String? source,
    int limit = 200,
  }) => _repo.getHistory(
    from: from,
    to: to,
    types: types,
    itemId: itemId,
    source: source,
    limit: limit,
  );
}

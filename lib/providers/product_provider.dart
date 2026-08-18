import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_logger.dart';
import '../data/repositories/product_repository.dart';
import '../models/product.dart';
import 'connectivity_provider.dart';
import '../core/services/audit_service.dart';
import '../models/order.dart';

String _actor(ConnectivityProvider? connectivity) {
  final name = connectivity?.currentUser?['name'] as String? ?? 'Admin';
  final role = connectivity?.currentUser?['role'] as String? ?? 'admin';
  return '$name ($role) @ ${Platform.localHostname}';
}

class ProductProvider extends ChangeNotifier {
  final ProductRepository _repo;

  ProductProvider({ProductRepository? repository})
    : _repo = repository ?? ProductRepository();

  List<Product> _products = [];
  bool _isLoading = false;
  final Map<int, int> _salesCountCache = {}; // Cache for sales counts

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> loadProducts({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final bool fetchRemote = connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote);

      _products = await _repo.getProducts(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );

      // Sotuvlar sonini yuklash — faqat remote rejimda EMAS
      if (!fetchRemote) {
        await _loadSalesCounts();
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSalesCounts() async {
    final counts = await _repo.getSalesCounts();
    _salesCountCache
      ..clear()
      ..addAll(counts);
  }

  int getProductSalesCount(int productId) {
    return _salesCountCache[productId] ?? 0;
  }

  Future<void> addProduct(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.addProduct(product, connectivity: connectivity);
      AppLogger.i('ProductProvider', 'Taom QOSHILDI | Nomi: ${product.name}, Narxi: ${product.price}, Kategoriya: ${product.category}${product.isSet ? " (SET)" : ""} | ${_actor(connectivity)}');
      await loadProducts(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('ProductProvider', 'Taom QOSHISHDA XATO | Nomi: ${product.name} | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  Future<void> updateProduct(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      final bool isClient =
          connectivity != null && connectivity.mode == ConnectivityMode.client;

      final oldProduct = await _repo.updateProduct(
        product,
        connectivity: connectivity,
      );

      // Audit: Mahsulot tahrirlanganda (faqat lokal/server rejimda)
      if (!isClient) {
        AuditService.instance.logAction(
          action: 'edit_product',
          entity: 'product',
          entityId: product.id.toString(),
          before: oldProduct,
          after: product.toMap(),
        );
      }
      AppLogger.i('ProductProvider', 'Taom TAHRIRLANDI | ID: ${product.id}, Nomi: ${product.name}, Narxi: ${product.price}, Kategoriya: ${product.category} | ${_actor(connectivity)}');
      await loadProducts(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('ProductProvider', 'Taom TAHRIRLASHDA XATO | ID: ${product.id}, Nomi: ${product.name} | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  Future<void> deleteProduct(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    final productName = _products.firstWhere((p) => p.id == id, orElse: () => Product(name: 'ID:$id', price: 0, category: '')).name;
    try {
      await _repo.deleteProduct(id, connectivity: connectivity);
      AppLogger.i('ProductProvider', 'Taom O\'CHIRILDI | ID: $id, Nomi: $productName | ${_actor(connectivity)}');
      await loadProducts(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('ProductProvider', 'Taom O\'CHIRISHDA XATO | ID: $id, Nomi: $productName | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  Future<void> reorderProducts(
    int oldIndex,
    int newIndex,
    String category, {
    ConnectivityProvider? connectivity,
  }) async {
    // Filter products by category for reordering context
    final categoryProducts = _products
        .where((p) => p.category == category)
        .toList();

    if (newIndex > oldIndex) newIndex--;
    final movedItem = categoryProducts[oldIndex];
    categoryProducts.removeAt(oldIndex);
    categoryProducts.insert(newIndex, movedItem);

    // Update sort_order for all products in this category
    for (int i = 0; i < categoryProducts.length; i++) {
      final updatedProduct = categoryProducts[i].copyWith(sortOrder: i);
      await _repo.updateProductRow(updatedProduct, connectivity: connectivity);
    }

    AppLogger.i('ProductProvider', 'Taomlar TARTIBI O\'ZGARTIRILDI | Kategoriya: $category, Ko\'chirildi: ${movedItem.name} ($oldIndex → $newIndex) | ${_actor(connectivity)}');
    await loadProducts(connectivity: connectivity);
  }

  void decrementQuantities(List<OrderItem> items) {
    bool changed = false;
    for (var item in items) {
      final index = _products.indexWhere((p) => p.id == item.productId);
      if (index != -1) {
        final product = _products[index];
        if (product.quantity != null) {
          _products[index] = product.copyWith(
            quantity: product.quantity! - item.qty,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      notifyListeners();
    }
  }
}

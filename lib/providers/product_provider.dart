import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/product.dart';
import 'connectivity_provider.dart';
import '../core/services/audit_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  Map<int, int> _salesCountCache = {}; // Cache for sales counts

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> loadProducts({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data;
      bool fetchRemote =
          connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote);

      if (fetchRemote) {
        final remoteData = await connectivity.getRemoteData('/products');
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        data = await DatabaseHelper.instance.database.then(
          (db) => db.query('products', orderBy: 'sort_order ASC'),
        );
      }

      final List<Product> loadedProducts = [];
      for (var item in data) {
        List<BundleItem>? bundleItems;
        if (item['is_set'] == 1) {
          if (fetchRemote) {
            if (item['bundle_items'] != null) {
              bundleItems = (item['bundle_items'] as List)
                  .map((bi) => BundleItem.fromMap(bi))
                  .toList();
            }
          } else {
            final bundleData = await DatabaseHelper.instance.queryByColumn(
              'product_bundles',
              'bundle_id',
              item['id'],
            );
            bundleItems = bundleData
                .map((bi) => BundleItem.fromMap(bi))
                .toList();
          }
        }
        loadedProducts.add(Product.fromMap(item, bundleItems: bundleItems));
      }
      _products = loadedProducts;

      // Load sales counts - only if NOT in remote mode
      if (!fetchRemote) {
        await _loadSalesCounts();
      }
    } catch (e) {
      debugPrint("Error loading products: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSalesCounts() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT product_id, SUM(qty) as total_sold
      FROM order_items
      GROUP BY product_id
    ''');

    _salesCountCache.clear();
    for (var row in result) {
      final productId = row['product_id'] as int;
      final totalSold = row['total_sold'] as int;
      _salesCountCache[productId] = totalSold;
    }
  }

  int getProductSalesCount(int productId) {
    return _salesCountCache[productId] ?? 0;
  }

  Future<void> addProduct(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/products', product.toMap());
    } else {
      final id = await DatabaseHelper.instance.insert(
        'products',
        product.toMap(),
      );

      // Save bundle items if it's a SET
      if (product.isSet && product.bundleItems != null) {
        for (var item in product.bundleItems!) {
          await DatabaseHelper.instance.insert(
            'product_bundles',
            item.copyWith(bundleId: id).toMap(),
          );
        }
      }
    }

    await loadProducts(connectivity: connectivity);
  }

  Future<void> updateProduct(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/products', product.toMap());
    } else {
      final oldProductMap = await DatabaseHelper.instance.queryByColumn(
        'products',
        'id',
        product.id,
      );
      final oldProduct = oldProductMap.isNotEmpty ? oldProductMap.first : null;

      await DatabaseHelper.instance.update(
        'products',
        product.toMap(),
        'id = ?',
        [product.id],
      );

      // Audit: Mahsulot tahrirlanganda
      AuditService.instance.logAction(
        action: 'edit_product',
        entity: 'product',
        entityId: product.id.toString(),
        before: oldProduct,
        after: product.toMap(),
      );

      // Update bundle items if it's a SET
      if (product.id != null) {
        // Clear existing and re-insert
        await DatabaseHelper.instance.delete(
          'product_bundles',
          'bundle_id = ?',
          [product.id],
        );

        if (product.isSet && product.bundleItems != null) {
          for (var item in product.bundleItems!) {
            await DatabaseHelper.instance.insert(
              'product_bundles',
              item.copyWith(bundleId: product.id!).toMap(),
            );
          }
        }
      }
    }

    await loadProducts(connectivity: connectivity);
  }

  Future<void> deleteProduct(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/products/$id');
    } else {
      await DatabaseHelper.instance.delete('products', 'id = ?', [id]);
    }
    await loadProducts(connectivity: connectivity);
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
    final item = categoryProducts.removeAt(oldIndex);
    categoryProducts.insert(newIndex, item);

    // Update sort_order for all products in this category
    for (int i = 0; i < categoryProducts.length; i++) {
      final updatedProduct = categoryProducts[i].copyWith(sortOrder: i);

      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        // In client mode, we might want a batch update if API supports it,
        // otherwise single updates. For now, following the pattern of single update.
        await connectivity.postRemoteData('/products', updatedProduct.toMap());
      } else {
        await DatabaseHelper.instance.update(
          'products',
          updatedProduct.toMap(),
          'id = ?',
          [updatedProduct.id],
        );
      }
    }

    await loadProducts(connectivity: connectivity);
  }
}

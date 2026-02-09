import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/product.dart';
import 'connectivity_provider.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  Map<int, int> _salesCountCache = {}; // Cache for sales counts

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> loadProducts([ConnectivityProvider? connectivity]) async {
    _isLoading = true;
    notifyListeners();

    final List<Map<String, dynamic>> data;
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final remoteData = await connectivity.getRemoteData('/products');
      data = List<Map<String, dynamic>>.from(remoteData);
    } else {
      data = await DatabaseHelper.instance.queryAll('products');
    }
    _products = data.map((item) => Product.fromMap(item)).toList();

    // Load sales counts
    await _loadSalesCounts();

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

  Future<void> addProduct(Product product) async {
    await DatabaseHelper.instance.insert('products', product.toMap());
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await DatabaseHelper.instance.update(
      'products',
      product.toMap(),
      'id = ?',
      [product.id],
    );
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.delete('products', 'id = ?', [id]);
    await loadProducts();
  }
}

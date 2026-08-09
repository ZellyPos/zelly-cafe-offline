import '../../core/database_helper.dart';
import '../../models/product.dart';
import '../../providers/connectivity_provider.dart';

/// Mahsulotlar va ular bilan bog'liq to'plam (`product_bundles`) uchun
/// ma'lumotlar qatlami.
///
/// Bundle'lar tufayli bu repozitoriy `BaseRepository`dan meros olmaydi —
/// yuklashda har bir SET mahsulot uchun bundle qatorlari ham o'qiladi/yoziladi.
/// Audit va logging provider (orkestratsiya) darajasida qoladi.
class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Barcha mahsulotlarni (SET mahsulotlar uchun bundle'lari bilan) qaytaradi.
  /// `client` rejimida remote'dan olib, lokalga (mahsulot + bundle) sinxronlaydi.
  Future<List<Product>> getProducts({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    final bool fetchRemote = connectivity != null &&
        connectivity.shouldFetchRemote(forceRemote: forceRemote);

    final List<Map<String, dynamic>> data;
    if (fetchRemote) {
      final remoteData = await connectivity.getRemoteData('/products');
      data = List<Map<String, dynamic>>.from(remoteData);

      // PrinterService kabi komponentlar uchun lokalga sinxronlash
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('products');
        await txn.delete('product_bundles');
        for (final item in data) {
          final productForDb = Map<String, dynamic>.from(item);
          // bundle_items faqat xotira/API uchun, DB ustuni emas
          productForDb.remove('bundle_items');
          await txn.insert('products', productForDb);

          if (item['is_set'] == 1 && item['bundle_items'] != null) {
            for (final bi in item['bundle_items']) {
              await txn.insert('product_bundles', {
                'bundle_id': productForDb['id'],
                'product_id': bi['product_id'],
                'qty': bi['qty'],
              });
            }
          }
        }
      });
    } else {
      final db = await _dbHelper.database;
      data = await db.query('products', orderBy: 'sort_order ASC');
    }

    final loaded = <Product>[];
    for (final item in data) {
      List<BundleItem>? bundleItems;
      if (item['is_set'] == 1) {
        if (fetchRemote) {
          if (item['bundle_items'] != null) {
            bundleItems = (item['bundle_items'] as List)
                .map((bi) => BundleItem.fromMap(bi))
                .toList();
          }
        } else {
          final bundleData = await _dbHelper.queryByColumn(
            'product_bundles',
            'bundle_id',
            item['id'],
          );
          bundleItems = bundleData.map((bi) => BundleItem.fromMap(bi)).toList();
        }
      }
      loaded.add(Product.fromMap(item, bundleItems: bundleItems));
    }
    return loaded;
  }

  /// Oxirgi 30 kunlik sotuvlar sonini mahsulot bo'yicha qaytaradi.
  Future<Map<int, int>> getSalesCounts() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT oi.product_id, SUM(oi.qty) as total_sold
      FROM order_items oi
      INNER JOIN orders o ON oi.order_id = o.id
      WHERE o.created_at >= date('now', '-30 days')
      GROUP BY oi.product_id
    ''');

    final counts = <int, int>{};
    for (final row in result) {
      final productId = (row['product_id'] as num).toInt();
      final totalSold = (row['total_sold'] as num).toInt();
      counts[productId] = totalSold;
    }
    return counts;
  }

  /// Mahsulotni `id` bo'yicha xom map ko'rinishida oladi (audit oldingi holati
  /// uchun). Topilmasa `null`.
  Future<Map<String, dynamic>?> getProductRaw(int? id) async {
    final res = await _dbHelper.queryByColumn('products', 'id', id);
    return res.isNotEmpty ? res.first : null;
  }

  /// Mahsulot qo'shadi (SET bo'lsa bundle'lari bilan). `client` rejimida
  /// remote'ga yuboradi.
  Future<void> addProduct(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/products', product.toMap());
      return;
    }
    final id = await _dbHelper.insert('products', product.toMap());
    if (product.isSet && product.bundleItems != null) {
      for (final item in product.bundleItems!) {
        await _dbHelper.insert(
          'product_bundles',
          item.copyWith(bundleId: id).toMap(),
        );
      }
    }
  }

  /// Mahsulotni yangilaydi (SET bo'lsa bundle'larini almashtiradi).
  ///
  /// Lokal rejimda yangilashdan OLDINGI mahsulot mapini qaytaradi (audit uchun);
  /// `client` rejimida `null`.
  Future<Map<String, dynamic>?> updateProduct(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/products', product.toMap());
      return null;
    }

    final oldProduct = await getProductRaw(product.id);

    await _dbHelper.update('products', product.toMap(), 'id = ?', [product.id]);

    // Bundle'larni yangilash (SET uchun): eskilarini o'chirib, qaytadan qo'shamiz
    if (product.id != null) {
      await _dbHelper.delete('product_bundles', 'bundle_id = ?', [product.id]);
      if (product.isSet && product.bundleItems != null) {
        for (final item in product.bundleItems!) {
          await _dbHelper.insert(
            'product_bundles',
            item.copyWith(bundleId: product.id!).toMap(),
          );
        }
      }
    }
    return oldProduct;
  }

  /// Mahsulotni `id` bo'yicha o'chiradi. `client` rejimida remote'ga yuboradi.
  Future<void> deleteProduct(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/products/$id');
    } else {
      await _dbHelper.delete('products', 'id = ?', [id]);
    }
  }

  /// Faqat mahsulot qatorini yangilaydi (bundle'larga tegmaydi) — tartiblash
  /// (reorder) uchun. `client` rejimida remote'ga yuboradi.
  Future<void> updateProductRow(
    Product product, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/products', product.toMap());
    } else {
      await _dbHelper.update('products', product.toMap(), 'id = ?', [product.id]);
    }
  }
}

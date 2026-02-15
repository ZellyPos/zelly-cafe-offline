import '../database_helper.dart';
import '../../models/analytics_models.dart';

/// AnalyticsService - Analitika va hisobotlarni tezkor hisoblash uchun servis
class AnalyticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // In-memory kesh
  final Map<String, dynamic> _cache = {};

  static final AnalyticsService instance = AnalyticsService._internal();
  AnalyticsService._internal();

  /// Keshni tozalash
  void clearCache() => _cache.clear();

  /// Kunlik sotuvlar statistikasi
  Future<List<DailySalesStats>> getDailySales({
    required DateTime start,
    required DateTime end,
    bool useCache = true,
  }) async {
    final cacheKey =
        'daily_${start.toIso8601String()}_${end.toIso8601String()}';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<DailySalesStats>;
    }

    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        DATE(created_at) as date,
        SUM(grand_total) as total,
        SUM(CASE WHEN LOWER(payment_type) LIKE '%naqd%' OR LOWER(payment_type) LIKE '%cash%' THEN grand_total ELSE 0 END) as cash,
        SUM(CASE WHEN LOWER(payment_type) LIKE '%karta%' OR LOWER(payment_type) LIKE '%card%' THEN grand_total ELSE 0 END) as card,
        SUM(CASE WHEN LOWER(payment_type) LIKE '%nasiya%' OR LOWER(payment_type) LIKE '%debt%' THEN grand_total ELSE 0 END) as debt,
        COUNT(id) as orders_count
      FROM orders
      WHERE status = 1 AND created_at BETWEEN ? AND ?
      GROUP BY DATE(created_at)
      ORDER BY date DESC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final stats = results.map((m) => DailySalesStats.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }

  /// Eng ko'p sotilgan mahsulotlar (Top Products)
  Future<List<ProductPerformance>> getTopProducts({
    required DateTime start,
    required DateTime end,
    int limit = 10,
    bool useCache = true,
  }) async {
    final cacheKey =
        'top_products_${start.toIso8601String()}_${end.toIso8601String()}_$limit';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<ProductPerformance>;
    }

    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        oi.product_id,
        oi.product_name,
        SUM(oi.qty) as qty,
        SUM(oi.qty * oi.price) as revenue
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      WHERE o.status = 1 AND o.created_at BETWEEN ? AND ?
      GROUP BY oi.product_id
      ORDER BY qty DESC
      LIMIT ?
    ''',
      [start.toIso8601String(), end.toIso8601String(), limit],
    );

    final stats = results.map((m) => ProductPerformance.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }

  /// Ofitsiantlar ish samaradorligi
  Future<List<WaiterPerformance>> getWaiterPerformance({
    required DateTime start,
    required DateTime end,
    bool useCache = true,
  }) async {
    final cacheKey =
        'waiter_perf_${start.toIso8601String()}_${end.toIso8601String()}';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<WaiterPerformance>;
    }

    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        o.waiter_id,
        COALESCE(w.name, 'Kassa') as waiter_name,
        COUNT(o.id) as orders_count,
        SUM(o.grand_total) as revenue,
        SUM(o.service_fee) as service_total
      FROM orders o
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE o.status = 1 AND o.created_at BETWEEN ? AND ?
      GROUP BY o.waiter_id
      ORDER BY revenue DESC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final stats = results.map((m) => WaiterPerformance.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }
}

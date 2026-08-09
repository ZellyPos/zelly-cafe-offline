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
    // Ichki so'rov: har bir buyurtma uchun to'lov turlarini agrega qiladi,
    // tashqi so'rov esa kunlik guruhga o'tkazadi.
    // Bu usul split-payment buyurtmalarida grand_total ni ikki marta sanashni oldini oladi.
    final results = await db.rawQuery(
      '''
      SELECT
        date,
        SUM(grand_total) as total,
        SUM(cash)        as cash,
        SUM(card)        as card,
        SUM(debt)        as debt,
        COUNT(*)         as orders_count
      FROM (
        SELECT
          DATE(o.created_at) as date,
          o.grand_total,
          COALESCE(SUM(CASE WHEN op.payment_type = 'cash'     THEN op.amount ELSE 0 END), 0) as cash,
          COALESCE(SUM(CASE WHEN op.payment_type = 'card'     THEN op.amount ELSE 0 END), 0) as card,
          COALESCE(SUM(CASE WHEN op.payment_type = 'debt'     THEN op.amount ELSE 0 END), 0) as debt
        FROM orders o
        LEFT JOIN order_payments op ON o.id = op.order_id
        WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
        GROUP BY o.id
      ) sub
      GROUP BY date
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
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
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
        SUM(o.service_total) as service_total,
        COALESCE(w.type, 0) as waiter_type,
        COALESCE(w.value, 0.0) as waiter_value
      FROM orders o
      LEFT JOIN waiters w ON o.waiter_id = w.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
      GROUP BY o.waiter_id
      ORDER BY revenue DESC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final stats = results.map((m) => WaiterPerformance.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }

  /// Stollar bo'yicha tushum
  Future<List<TablePerformance>> getTablePerformance({
    required DateTime start,
    required DateTime end,
    int limit = 10,
    bool useCache = true,
  }) async {
    final cacheKey =
        'table_perf_${start.toIso8601String()}_${end.toIso8601String()}_$limit';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<TablePerformance>;
    }

    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        o.table_id,
        t.name as table_name,
        COUNT(o.id) as orders_count,
        SUM(o.grand_total) as revenue
      FROM orders o
      JOIN tables t ON o.table_id = t.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
      GROUP BY o.table_id
      ORDER BY revenue DESC
      LIMIT ?
    ''',
      [start.toIso8601String(), end.toIso8601String(), limit],
    );

    final stats = results.map((m) => TablePerformance.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }

  /// Zallar (Locations) bo'yicha tushum
  Future<List<LocationPerformance>> getLocationPerformance({
    required DateTime start,
    required DateTime end,
    bool useCache = true,
  }) async {
    final cacheKey =
        'location_perf_${start.toIso8601String()}_${end.toIso8601String()}';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<LocationPerformance>;
    }

    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        o.location_id,
        l.name as location_name,
        SUM(o.grand_total) as revenue
      FROM orders o
      JOIN locations l ON o.location_id = l.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
      GROUP BY o.location_id
      ORDER BY revenue DESC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final stats = results.map((m) => LocationPerformance.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }

  /// Kategoriyalar bo'yicha sotuvlar
  Future<List<CategorySalesStats>> getCategoryBreakdown({
    required DateTime start,
    required DateTime end,
    bool useCache = true,
  }) async {
    final cacheKey =
        'category_${start.toIso8601String()}_${end.toIso8601String()}';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<CategorySalesStats>;
    }
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT COALESCE(p.category, 'Boshqa') as category,
             SUM(oi.qty) as qty,
             SUM(oi.qty * oi.price) as revenue
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      JOIN orders o ON oi.order_id = o.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
      GROUP BY p.category ORDER BY revenue DESC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final stats = results.map((m) => CategorySalesStats.fromMap(m)).toList();
    _cache[cacheKey] = stats;
    return stats;
  }

  /// Soatlik faollik (0-23 soat)
  Future<List<HourlySalesStats>> getHourlyBreakdown({
    required DateTime start,
    required DateTime end,
    bool useCache = true,
  }) async {
    final cacheKey =
        'hourly_${start.toIso8601String()}_${end.toIso8601String()}';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<HourlySalesStats>;
    }
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT CAST(strftime('%H', created_at) AS INTEGER) as hour,
             COUNT(*) as orders_count,
             SUM(grand_total) as revenue
      FROM orders WHERE status = 1 AND created_at >= ? AND created_at < ?
      GROUP BY hour ORDER BY hour ASC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final map = {for (var r in results) (r['hour'] as int): r};
    final stats = List.generate(24, (h) {
      final r = map[h];
      return HourlySalesStats(
        hour: h,
        ordersCount: r != null ? (r['orders_count'] as num).toInt() : 0,
        revenue: r != null ? (r['revenue'] as num).toDouble() : 0.0,
      );
    });
    _cache[cacheKey] = stats;
    return stats;
  }

  /// To'lov turlari bo'yicha taqsimot
  Future<List<PaymentTypeStats>> getPaymentBreakdown({
    required DateTime start,
    required DateTime end,
    bool useCache = true,
  }) async {
    final cacheKey =
        'payment_breakdown_${start.toIso8601String()}_${end.toIso8601String()}';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<PaymentTypeStats>;
    }

    final db = await _dbHelper.database;
    final totalResult = await db.rawQuery(
      'SELECT SUM(grand_total) as total FROM orders WHERE status = 1 AND created_at >= ? AND created_at < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final total = (totalResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final results = await db.rawQuery(
      '''
      SELECT op.payment_type, SUM(op.amount) as amount
      FROM order_payments op
      JOIN orders o ON op.order_id = o.id
      WHERE o.status = 1 AND o.created_at >= ? AND o.created_at < ?
      GROUP BY op.payment_type
      ORDER BY amount DESC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final stats = results
        .map((m) => PaymentTypeStats.fromMap(m, total))
        .toList();
    _cache[cacheKey] = stats;
    return stats;
  }
}

import '../../models/table.dart';
import '../../providers/connectivity_provider.dart';
import 'base_repository.dart';

/// Stollar uchun ma'lumotlar qatlami.
///
/// Yuklashda har bir stolning aktiv buyurtmasi (`orders`) va ofitsiant nomi
/// (`waiters`) JOIN orqali biriktiriladi. `add`/`deleteById` [BaseRepository]dan
/// meros olinadi; qolgan operatsiyalar stolga xos.
class TableRepository extends BaseRepository<TableModel> {
  @override
  String get table => 'tables';

  @override
  String get remotePath => '/tables';

  @override
  TableModel fromMap(Map<String, dynamic> map) => TableModel.fromMap(map);

  @override
  Map<String, dynamic> toMap(TableModel item) => item.toMap();

  @override
  int? idOf(TableModel item) => item.id;

  /// Aktiv buyurtma bilan birga barcha stollarni JOIN orqali oladi.
  /// `client` rejimida `/tables/summary` dan olib, lokalga sinxronlaydi.
  static const String _joinQuery = '''
      SELECT t.*,
             o.id as order_id,
             o.waiter_id,
             o.opened_at,
             o.total as order_total,
             o.bill_requested,
             o.bill_requested_at,
             w.name as waiter_name
      FROM tables t
      LEFT JOIN orders o ON t.active_order_id = o.id AND o.status = 0
      LEFT JOIN waiters w ON o.waiter_id = w.id
    ''';

  Future<List<TableModel>> getAllWithOrders({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    if (connectivity != null &&
        connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
      final remoteData = await connectivity.getRemoteData('/tables/summary');
      final data = List<Map<String, dynamic>>.from(remoteData);

      // Komponentlar (masalan PrinterService) uchun lokalga sinxronlash
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('tables');
        for (final item in data) {
          await txn.insert('tables', {
            'id': item['id'],
            'location_id': item['location_id'],
            'name': item['name'],
            'status': item['status'],
            'pricing_type': item['pricing_type'],
            'hourly_rate': item['hourly_rate'],
            'fixed_amount': item['fixed_amount'],
            'active_order_id': item['active_order_id'],
            'x': item['x'],
            'y': item['y'],
            'width': item['width'],
            'height': item['height'],
            'shape': item['shape'],
            'service_percentage': item['service_percentage'],
          });
        }
      });
      return data.map(_mapRow).toList();
    }

    final db = await dbHelper.database;
    final data = await db.rawQuery(_joinQuery);
    return data.map(_mapRow).toList();
  }

  /// Berilgan joydagi stollarni (aktiv buyurtmasi bilan) oladi.
  Future<List<TableModel>> getTablesForLocation(int? locationId) async {
    final db = await dbHelper.database;
    final whereArgs = <dynamic>[];
    var query = _joinQuery;
    if (locationId != null) {
      query += ' WHERE t.location_id = ?';
      whereArgs.add(locationId);
    }
    final data = await db.rawQuery(query, whereArgs);
    return data.map(_mapRow).toList();
  }

  /// Stolni yangilaydi, biroq `active_order_id`ni tegmaydi — u faqat buyurtma
  /// ochilganda/yopilganda o'zgaradi. Aks holda admin sozlamani o'zgartirganda
  /// aktiv buyurtma bog'liqligi uzilib qolardi.
  Future<void> updatePreservingOrder(
    TableModel table, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', table.toMap());
    } else {
      final updateMap = Map<String, dynamic>.from(table.toMap())
        ..remove('active_order_id');
      await dbHelper.update('tables', updateMap, 'id = ?', [table.id]);
    }
  }

  /// Stol holatini (bo'sh/band) yangilaydi.
  Future<void> updateStatus(
    int id,
    int status, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', {'id': id, 'status': status});
    } else {
      await dbHelper.update('tables', {'status': status}, 'id = ?', [id]);
    }
  }

  /// Stolning zal rejasidagi joylashuvini (x/y/o'lcham) yangilaydi.
  Future<void> updateLayout(
    int id,
    double x,
    double y,
    double width,
    double height, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/tables', {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
    } else {
      await dbHelper.update(
        'tables',
        {'x': x, 'y': y, 'width': width, 'height': height},
        'id = ?',
        [id],
      );
    }
  }

  /// Stolda ochiq buyurtma (status=0) bor-yo'qligini tekshiradi (o'chirish uchun).
  Future<int> countOpenOrders(int tableId) async {
    final db = await dbHelper.database;
    final openOrders = await db.query(
      'orders',
      where: 'table_id = ? AND status = 0',
      whereArgs: [tableId],
    );
    return openOrders.length;
  }

  /// Ommaviy narx turi yangilash.
  Future<void> bulkUpdatePricing({
    required int pricingType,
    required double value,
    int? onlyLocationId,
    int? onlyCurrentPricingType,
  }) async {
    final db = await dbHelper.database;
    final conditions = <String>[];
    if (onlyLocationId != null) conditions.add('location_id = $onlyLocationId');
    if (onlyCurrentPricingType != null) {
      conditions.add('pricing_type = $onlyCurrentPricingType');
    }
    final where = conditions.isEmpty ? '1=1' : conditions.join(' AND ');

    final double hourlyRate = pricingType == 1 ? value : 0;
    final double fixedAmount = pricingType == 2 ? value : 0;
    final double servicePercentage = pricingType == 3 ? value : 0;

    await db.rawUpdate(
      'UPDATE tables SET pricing_type = ?, hourly_rate = ?, fixed_amount = ?, service_percentage = ? WHERE $where',
      [pricingType, hourlyRate, fixedAmount, servicePercentage],
    );
  }

  /// So'rov satrini (JOIN natijasi) [TableModel]ga aylantiradi.
  TableModel _mapRow(Map<String, dynamic> item) {
    ActiveOrderInfo? activeOrder;
    if (item['order_id'] != null) {
      activeOrder = ActiveOrderInfo(
        orderId: item['order_id'] as String,
        waiterId: item['waiter_id'] as int?,
        waiterName: item['waiter_name'] as String?,
        totalAmount: (item['order_total'] as num).toDouble(),
        openedAt: item['opened_at'] != null
            ? DateTime.parse(item['opened_at'] as String)
            : null,
        billRequested: (item['bill_requested'] as int? ?? 0) == 1,
        billRequestedAt: item['bill_requested_at'] != null
            ? DateTime.parse(item['bill_requested_at'] as String)
            : null,
      );
    }
    return TableModel.fromMap(item, activeOrder: activeOrder);
  }
}

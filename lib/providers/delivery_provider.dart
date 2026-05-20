import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database_helper.dart';
import '../core/printing_service.dart';
import '../core/services/telegram_bot_service.dart';
import '../models/order.dart';
import '../models/courier.dart';
import '../models/delivery_zone.dart';
import '../models/product.dart';
import 'cart_provider.dart';

class DeliveryProvider extends ChangeNotifier {
  // ── Couriers ──────────────────────────────────────────────────────────────
  List<Courier> _couriers = [];
  List<Courier> get couriers => _couriers;
  List<Courier> get activeCouriers => _couriers.where((c) => c.isActive).toList();

  // ── Zones ─────────────────────────────────────────────────────────────────
  List<DeliveryZone> _zones = [];
  List<DeliveryZone> get zones => _zones;
  List<DeliveryZone> get activeZones => _zones.where((z) => z.isActive).toList();

  // ── Active delivery orders ─────────────────────────────────────────────────
  List<Order> _orders = [];
  List<Order> get orders => _filteredOrders(_orders);
  List<Order> get newOrders => _filteredOrders(_orders.where((o) => o.deliveryStatus == 0).toList());
  List<Order> get preparingOrders => _filteredOrders(_orders.where((o) => o.deliveryStatus == 1).toList());
  List<Order> get onWayOrders => _filteredOrders(_orders.where((o) => o.deliveryStatus == 2).toList());
  List<Order> get deliveredOrders => _filteredOrders(_orders.where((o) => o.deliveryStatus == 3).toList());

  // ── Filters ────────────────────────────────────────────────────────────────
  DateTime? filterDateStart;
  DateTime? filterDateEnd;
  int? filterCourierId; // null = all

  List<Order> _filteredOrders(List<Order> src) {
    return src.where((o) {
      if (filterCourierId != null && o.courierId != filterCourierId) return false;
      return true;
    }).toList();
  }

  void setDateFilter(DateTime? start, DateTime? end) {
    filterDateStart = start;
    filterDateEnd = end;
    loadOrders();
  }

  void setCourierFilter(int? courierId) {
    filterCourierId = courierId;
    notifyListeners();
  }

  // ── New order cart state ────────────────────────────────────────────────────
  final Map<int, CartItem> _cartItems = {};
  Map<int, CartItem> get cartItems => Map.unmodifiable(_cartItems);

  String customerName = '';
  String customerPhone = '';
  String deliveryAddress = '';
  String deliveryNote = '';
  double deliveryFee = 0;
  int? selectedCourierId;
  int? selectedZoneId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  double get cartTotal => _cartItems.values.fold(0.0, (s, i) => s + i.total);
  double get grandTotal => cartTotal + deliveryFee;
  bool get cartIsEmpty => _cartItems.isEmpty;

  // ── Load all ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Future.wait([loadCouriers(), loadZones(), loadOrders()]);
  }

  // ── Couriers ───────────────────────────────────────────────────────────────

  Future<void> loadCouriers() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('couriers', orderBy: 'name ASC');
    _couriers = rows.map(Courier.fromMap).toList();
    notifyListeners();
  }

  Future<void> addCourier(String name, String? phone) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('couriers', {
      'name': name,
      'phone': phone,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    await loadCouriers();
  }

  Future<void> updateCourier(Courier c) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('couriers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    await loadCouriers();
  }

  Future<void> deleteCourier(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('couriers', where: 'id = ?', whereArgs: [id]);
    await loadCouriers();
  }

  // ── Courier stats ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCourierStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.phone,
        COUNT(o.id) as deliveries,
        SUM(o.grand_total) as revenue,
        SUM(o.delivery_fee) as delivery_fees
      FROM couriers c
      LEFT JOIN orders o ON o.courier_id = c.id
        AND o.status = 1
        AND o.order_type = 2
        AND o.created_at BETWEEN ? AND ?
      GROUP BY c.id
      ORDER BY deliveries DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  // ── Zones ──────────────────────────────────────────────────────────────────

  Future<void> loadZones() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('delivery_zones', orderBy: 'name ASC');
    _zones = rows.map(DeliveryZone.fromMap).toList();
    notifyListeners();
  }

  Future<void> addZone(String name, double fee, String color) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('delivery_zones', {'name': name, 'fee': fee, 'color': color, 'is_active': 1});
    await loadZones();
  }

  Future<void> updateZone(DeliveryZone z) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('delivery_zones', z.toMap(), where: 'id = ?', whereArgs: [z.id]);
    await loadZones();
  }

  Future<void> deleteZone(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('delivery_zones', where: 'id = ?', whereArgs: [id]);
    await loadZones();
  }

  void setSelectedZone(int? zoneId) {
    selectedZoneId = zoneId;
    if (zoneId != null) {
      final zone = _zones.firstWhere((z) => z.id == zoneId, orElse: () => const DeliveryZone(name: '', fee: 0));
      deliveryFee = zone.fee;
    } else {
      deliveryFee = 0;
    }
    notifyListeners();
  }

  // ── Customer phone lookup ──────────────────────────────────────────────────

  /// Search customers + last delivery address by phone prefix.
  Future<List<Map<String, dynamic>>> lookupByPhone(String phone) async {
    if (phone.length < 3) return [];
    final db = await DatabaseHelper.instance.database;
    // Check customers table
    final customers = await db.rawQuery('''
      SELECT name, phone, NULL as address
      FROM customers
      WHERE phone LIKE ?
      LIMIT 5
    ''', ['%$phone%']);

    // Also check last delivery orders with that phone
    final orders = await db.rawQuery('''
      SELECT customer_name as name, customer_phone as phone, delivery_address as address
      FROM orders
      WHERE order_type = 2 AND customer_phone LIKE ? AND delivery_address IS NOT NULL
      GROUP BY customer_phone
      ORDER BY created_at DESC
      LIMIT 5
    ''', ['%$phone%']);

    // Merge, deduplicate by phone
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in [...customers, ...orders]) {
      final p = row['phone'] as String? ?? '';
      if (!seen.contains(p)) {
        seen.add(p);
        result.add(Map<String, dynamic>.from(row));
      }
    }
    return result;
  }

  // ── Active orders ──────────────────────────────────────────────────────────

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DatabaseHelper.instance.database;

      final start = filterDateStart ?? DateTime.now();
      final end = filterDateEnd ?? DateTime.now().add(const Duration(days: 1));
      final startStr = DateTime(start.year, start.month, start.day).toIso8601String();
      final endStr = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

      final rows = await db.rawQuery('''
        SELECT o.*, c.name as courier_name
        FROM orders o
        LEFT JOIN couriers c ON o.courier_id = c.id
        WHERE o.order_type = 2
          AND (o.status = 0 OR (o.status = 1 AND o.created_at BETWEEN ? AND ?))
        ORDER BY o.created_at DESC
      ''', [startStr, endStr]);

      final List<Order> result = [];
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        final orderId = map['id'] as String;
        final itemRows = await db.rawQuery('''
          SELECT oi.*, p.name as product_name
          FROM order_items oi
          LEFT JOIN products p ON oi.product_id = p.id
          WHERE oi.order_id = ?
        ''', [orderId]);
        final items = itemRows.map((r) => OrderItem.fromMap(Map<String, dynamic>.from(r))).toList();
        result.add(Order.fromMap(map, items: items));
      }
      _orders = result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDeliveryStatus(String orderId, int status) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('orders', {'delivery_status': status}, where: 'id = ?', whereArgs: [orderId]);
    await loadOrders();
  }

  Future<String?> checkoutOrder(String orderId, String paymentType, double paidAmount) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final orderRows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      if (orderRows.isEmpty) return 'Buyurtma topilmadi';

      final map = Map<String, dynamic>.from(orderRows.first);
      final grandT = (map['grand_total'] as num?)?.toDouble() ?? 0.0;
      final change = paidAmount > grandT ? paidAmount - grandT : 0.0;

      await db.update('orders', {
        'status': 1,
        'delivery_status': 3,
        'payment_type': paymentType,
        'paid_amount': paidAmount,
        'receipt_change': change,
        'closed_at': now.toIso8601String(),
      }, where: 'id = ?', whereArgs: [orderId]);

      final updatedMap = Map<String, dynamic>.from(
        (await db.query('orders', where: 'id = ?', whereArgs: [orderId])).first,
      );
      final itemRows = await db.rawQuery('''
        SELECT oi.*, p.name as product_name
        FROM order_items oi
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
      ''', [orderId]);
      final items = itemRows.map((r) => OrderItem.fromMap(Map<String, dynamic>.from(r))).toList();
      final order = Order.fromMap(updatedMap, items: items);

      try { await PrintingService.printReceipt(order: order); } catch (_) {}

      await loadOrders();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── New order cart ─────────────────────────────────────────────────────────

  void addItem(Product product) {
    if (_cartItems.containsKey(product.id)) {
      _cartItems[product.id!]!.quantity += 1;
    } else {
      _cartItems[product.id!] = CartItem(product: product, quantity: 1);
    }
    notifyListeners();
  }

  void updateQty(int productId, double qty) {
    if (qty <= 0) {
      _cartItems.remove(productId);
    } else if (_cartItems.containsKey(productId)) {
      _cartItems[productId]!.quantity = qty;
    }
    notifyListeners();
  }

  void setDeliveryFee(double fee) {
    deliveryFee = fee;
    selectedZoneId = null; // manual override clears zone
    notifyListeners();
  }

  void setSelectedCourier(int? id) {
    selectedCourierId = id;
    notifyListeners();
  }

  void clearNewOrder() {
    _cartItems.clear();
    customerName = '';
    customerPhone = '';
    deliveryAddress = '';
    deliveryNote = '';
    deliveryFee = 0;
    selectedCourierId = null;
    selectedZoneId = null;
    notifyListeners();
  }

  Future<String?> createOrder({int? waiterId}) async {
    if (_cartItems.isEmpty) return 'Buyurtmaga mahsulot qo\'shing';
    if (customerName.trim().isEmpty) return 'Mijoz ismini kiriting';
    if (deliveryAddress.trim().isEmpty) return 'Manzilni kiriting';

    try {
      final db = await DatabaseHelper.instance.database;
      final orderId = const Uuid().v4();
      final now = DateTime.now();
      final foodTotal = cartTotal;
      final gTotal = foodTotal + deliveryFee;

      final dayStart = await DatabaseHelper.instance.getDayStartTime();
      final countRes = await db.rawQuery(
        'SELECT MAX(daily_number) as max_no FROM orders WHERE created_at >= ?',
        [dayStart.toIso8601String()],
      );
      final dailyNo = ((countRes.first['max_no'] as int?) ?? 0) + 1;

      await db.insert('orders', {
        'id': orderId,
        'total': gTotal,
        'grand_total': gTotal,
        'food_total': foodTotal,
        'room_total': 0,
        'service_total': 0,
        'delivery_fee': deliveryFee,
        'payment_type': 'Pending',
        'created_at': now.toIso8601String(),
        'opened_at': now.toIso8601String(),
        'order_type': 2,
        'status': 0,
        'delivery_status': 0,
        'waiter_id': waiterId,
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone.trim(),
        'delivery_address': deliveryAddress.trim(),
        'delivery_note': deliveryNote.trim(),
        'courier_id': selectedCourierId,
        'zone_id': selectedZoneId,
        'daily_number': dailyNo,
      });

      for (final entry in _cartItems.entries) {
        final item = entry.value;
        await db.insert('order_items', {
          'order_id': orderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'qty': item.quantity,
          'unit': item.product.unit,
          'price': item.product.price,
          'printed_qty': 0,
        });
      }

      // Kitchen print
      final printItems = _cartItems.values.map((ci) => OrderItem(
        orderId: orderId,
        productId: ci.product.id!,
        productName: ci.product.name,
        qty: ci.quantity,
        unit: ci.product.unit,
        price: ci.product.price,
      )).toList();

      try {
        await PrintingService.printDividedOrder(
          order: Order(
            id: orderId,
            total: gTotal,
            grandTotal: gTotal,
            foodTotal: foodTotal,
            deliveryFee: deliveryFee,
            paymentType: 'Pending',
            createdAt: now,
            items: printItems,
            orderType: 2,
            status: 0,
            waiterId: waiterId,
            customerName: customerName.trim(),
            customerPhone: customerPhone.trim(),
            deliveryAddress: deliveryAddress.trim(),
            dailyNumber: dailyNo,
          ),
        );
      } catch (_) {}

      // Telegram notification
      try {
        final itemSummary = _cartItems.values
            .map((ci) => '${ci.product.name} ×${ci.quantity.toStringAsFixed(ci.quantity == ci.quantity.floorToDouble() ? 0 : 1)}')
            .join(', ');
        await TelegramBotService.instance.notifyNewDelivery(
          customerName: customerName.trim(),
          phone: customerPhone.trim(),
          address: deliveryAddress.trim(),
          total: gTotal,
          deliveryFee: deliveryFee,
          dailyNumber: dailyNo,
          itemsSummary: itemSummary,
          note: deliveryNote.trim(),
        );
      } catch (_) {}

      clearNewOrder();
      await loadOrders();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

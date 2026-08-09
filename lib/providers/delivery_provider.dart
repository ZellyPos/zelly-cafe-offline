import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/repositories/delivery_repository.dart';
import '../core/printing_service.dart';
import '../core/services/telegram_bot_service.dart';
import '../models/order.dart';
import '../models/courier.dart';
import '../models/delivery_zone.dart';
import '../models/product.dart';
import 'cart_provider.dart';

class DeliveryProvider extends ChangeNotifier {
  final DeliveryRepository _repo;

  DeliveryProvider({DeliveryRepository? repository})
    : _repo = repository ?? DeliveryRepository();

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
    _couriers = await _repo.getCouriers();
    notifyListeners();
  }

  Future<void> addCourier(String name, String? phone) async {
    await _repo.addCourier(name, phone);
    await loadCouriers();
  }

  Future<void> updateCourier(Courier c) async {
    await _repo.updateCourier(c);
    await loadCouriers();
  }

  Future<void> deleteCourier(int id) async {
    await _repo.deleteCourier(id);
    await loadCouriers();
  }

  // ── Courier stats ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCourierStats({
    required DateTime start,
    required DateTime end,
  }) {
    return _repo.getCourierStats(start: start, end: end);
  }

  // ── Zones ──────────────────────────────────────────────────────────────────

  Future<void> loadZones() async {
    _zones = await _repo.getZones();
    notifyListeners();
  }

  Future<void> addZone(String name, double fee, String color) async {
    await _repo.addZone(name, fee, color);
    await loadZones();
  }

  Future<void> updateZone(DeliveryZone z) async {
    await _repo.updateZone(z);
    await loadZones();
  }

  Future<void> deleteZone(int id) async {
    await _repo.deleteZone(id);
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
  Future<List<Map<String, dynamic>>> lookupByPhone(String phone) {
    return _repo.lookupByPhone(phone);
  }

  // ── Active orders ──────────────────────────────────────────────────────────

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      _orders = await _repo.getActiveOrders(
        filterStart: filterDateStart,
        filterEnd: filterDateEnd,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDeliveryStatus(String orderId, int status) async {
    await _repo.updateDeliveryStatus(orderId, status);
    await loadOrders();
  }

  // Buyurtmaga kurier biriktirish + status = 2 (yo'lda)
  Future<void> assignCourier({
    required String orderId,
    required int courierId,
  }) async {
    await _repo.assignCourier(orderId, courierId);
    await loadOrders();
  }

  // Buyurtmani yetkazildi deb belgilash
  Future<void> markDelivered(String orderId) async {
    await _repo.markDelivered(orderId);
    await loadOrders();
  }

  // Kurierni faollashtirish/o'chirish
  Future<void> toggleCourierStatus(int courierId, bool isActive) async {
    await _repo.setCourierActive(courierId, isActive);
    await loadCouriers();
  }

  // Kurierning hozirgi yo'ldagi buyurtmalar soni
  int getCourierActiveCount(int courierId) =>
      _orders.where((o) =>
        o.courierId == courierId &&
        (o.deliveryStatus == 1 || o.deliveryStatus == 2)
      ).length;

  Future<String?> checkoutOrder(String orderId, String paymentType, double paidAmount) async {
    try {
      final order = await _repo.closeOrder(orderId, paymentType, paidAmount);
      if (order == null) return 'Buyurtma topilmadi';

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
      final orderId = const Uuid().v4();
      final now = DateTime.now();
      final foodTotal = cartTotal;
      final gTotal = foodTotal + deliveryFee;

      final dailyNo = await _repo.getNextDailyNumber();

      final orderMap = {
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
      };

      final itemRows = _cartItems.entries.map((entry) {
        final item = entry.value;
        return {
          'order_id': orderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'qty': item.quantity,
          'unit': item.product.unit,
          'price': item.product.price,
          'printed_qty': 0,
        };
      }).toList();

      await _repo.createOrder(orderMap, itemRows);

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

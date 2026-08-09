import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../data/repositories/order_repository.dart';
import '../core/app_strings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../core/printing_service.dart';
import '../core/server/websocket_manager.dart';
import 'table_provider.dart';
import 'location_provider.dart';
import 'waiter_provider.dart';
import 'connectivity_provider.dart';
import 'app_settings_provider.dart';
import 'product_provider.dart';
import '../core/services/audit_service.dart';
import '../core/services/inventory_service.dart';
import 'shift_provider.dart';
import '../models/table.dart' as table_model;

class CartItem {
  Product product;
  double quantity;
  double printedQuantity;
  double discountAmount;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    this.printedQuantity = 0.0,
    this.discountAmount = 0.0,
  });

  double get total =>
      (product.price * quantity - discountAmount).clamp(0.0, double.infinity);
  double get originalTotal => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  final OrderRepository _repo;

  CartProvider({OrderRepository? repository})
    : _repo = repository ?? OrderRepository();

  final Map<int, CartItem> _items = {};
  String? _lastPrintError;

  Timer? _syncDebounce;
  // Faqat bitta _syncItems bir vaqtda ishlashi uchun mutex
  bool _isSyncing = false;

  @override
  void dispose() {
    _syncDebounce?.cancel();
    super.dispose();
  }

  // Restaurant Mode state
  int? _activeTableId;
  String? _activeOrderId;
  int? _activeWaiterId;
  int? _activeLocationId;
  DateTime? _activeOpenedAt;
  int _activeOrderType = 0; // 0: Dine-in, 1: Saboy

  bool _isNewOrderSession = false;

  // Order-level discount state
  String? _orderDiscountType;   // 'percent' | 'fixed'
  double _orderDiscountValue = 0;
  String? _orderDiscountNote;

  Map<int, CartItem> get items => _items;
  String? get lastPrintError => _lastPrintError;
  int? get activeTableId => _activeTableId;
  int? get activeWaiterId => _activeWaiterId;
  String? get activeOrderId => _activeOrderId;
  DateTime? get activeOpenedAt => _activeOpenedAt;

  String? get orderDiscountType => _orderDiscountType;
  double get orderDiscountValue => _orderDiscountValue;
  String? get orderDiscountNote => _orderDiscountNote;

  double get orderDiscountAmount {
    if (_orderDiscountType == null || _orderDiscountValue <= 0) return 0;
    final food = totalAmount; // already includes item discounts
    if (_orderDiscountType == 'percent') {
      return (food * _orderDiscountValue / 100).clamp(0.0, food);
    }
    return _orderDiscountValue.clamp(0.0, food);
  }

  bool get hasUnconfirmedChanges {
    return _items.values.any((item) => item.quantity != item.printedQuantity);
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.total;
    });
    return total;
  }

  double get totalForServiceCharge {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      if (!cartItem.product.noServiceCharge) {
        total += cartItem.total;
      }
    });
    return total;
  }

  bool hasPermission(BuildContext context, String permissionId) {
    final connectivity = context.read<ConnectivityProvider>();
    final role = connectivity.currentUser?['role'] ?? 'admin';

    // Admin has all permissions
    if (role == 'admin') return true;

    if (role == 'cashier') {
      // Unrestricted core POS actions for cashiers (default permissions)
      final coreActions = [
        'print',
        'checkout',
        'delete',
        'reduce',
        'confirm',
        'cancel',
      ];
      if (coreActions.any((action) => permissionId.contains(action))) {
        // Return true for core actions if the role is cashier
        return true;
      }

      final userPerms = connectivity.currentUser?['permissions'];

      // No permissions field set → cashier has full access (default behavior)
      if (userPerms == null) return true;

      if (userPerms is List) {
        // Empty list → full access (no restrictions configured)
        if (userPerms.isEmpty) return true;
        return userPerms.contains(permissionId);
      } else if (userPerms is String) {
        // Empty string → full access (no restrictions configured)
        if (userPerms.isEmpty) return true;
        final list = userPerms.split(',').where((s) => s.isNotEmpty).toList();
        // Check for exact match OR the core action match if it's in the list
        return list.contains(permissionId);
      }
      return true;
    }

    if (role == 'waiter') {
      // 1. If we have permissions in currentUser map, use them (List or String)
      final userPerms = connectivity.currentUser?['permissions'];
      if (userPerms != null) {
        if (userPerms is List) {
          return userPerms.contains(permissionId);
        } else if (userPerms is String && userPerms.isNotEmpty) {
          return userPerms.split(',').contains(permissionId);
        }
      }

      // 2. Fallback to checking _activeWaiterId (local waiter table)
      if (_activeWaiterId == null) return false;

      try {
        final waiterProvider = context.read<WaiterProvider>();
        final waiter = waiterProvider.waiters.firstWhere(
          (w) => w.id == _activeWaiterId,
        );
        return waiter.permissions.contains(permissionId);
      } catch (e) {
        return false;
      }
    }

    return false;
  }

  Future<bool> checkPermission(
    BuildContext context,
    String permissionId,
  ) async {
    if (hasPermission(context, permissionId)) return true;

    // If no permission, show error
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ushbu amal uchun ruxsatingiz yo\'q ($permissionId)'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  void refresh() {
    notifyListeners();
  }

  double getProductCartQuantity(int productId) {
    if (_items.containsKey(productId)) {
      return _items[productId]!.quantity;
    }
    return 0;
  }

  void setWaiter(int? waiterId, [BuildContext? context]) async {
    final oldWaiterId = _activeWaiterId;
    _activeWaiterId = waiterId;
    
    // Recalculate totals and sync order header (which now saves waiter_id to SQLite)
    await _syncOrderHeader(context);

    // If client mode, sync immediately to server
    if (context != null) {
      final connectivity = context.read<ConnectivityProvider>();
      if (connectivity.mode == ConnectivityMode.client) {
        await _syncItems(connectivity, context);
      } else {
        // standalone/server mode: immediately update local SQLite orders table
        if (_activeOrderId != null) {
          await _repo.updateOrderWaiter(_activeOrderId!, waiterId);
        }
        // Broadcast the update so other terminals and the local TablesScreen immediately reload
        if (_activeTableId != null) {
          WebSocketManager.instance.broadcast('tables_updated', {
            'table_id': _activeTableId!,
          });
        }
      }
    } else {
      // Fallback update without context
      if (_activeOrderId != null) {
        await _repo.updateOrderWaiter(_activeOrderId!, waiterId);
      }
    }

    // Audit: Ofitsiant o'zgarganda
    if (_activeOrderId != null && oldWaiterId != waiterId) {
      AuditService.instance.logAction(
        action: 'change_waiter',
        entity: 'order',
        entityId: _activeOrderId!,
        before: {'waiter_id': oldWaiterId},
        after: {'waiter_id': waiterId},
      );
    }

    notifyListeners();
  }

  Future<void> loadTableOrder(
    int? tableId,
    int? locationId, [
    ConnectivityProvider? connectivity,
    int orderType = 0,
    String? orderId,
  ]) async {
    _activeTableId = tableId;
    _activeLocationId = locationId;
    _activeOrderType = orderType;
    _items.clear();
    _activeOrderId = null;
    _activeWaiterId = null;
    _activeOpenedAt = null;
    _isNewOrderSession = false;
    _orderDiscountType = null;
    _orderDiscountValue = 0;
    _orderDiscountNote = null;

    // Load a specific order by ID (e.g. a specific saboy order)
    if (orderId != null && tableId == null) {
      final orderMap = await _repo.getOpenOrderById(orderId);
      if (orderMap != null) {
        _activeOrderId = orderMap['id'] as String;
        _activeWaiterId = orderMap['waiter_id'] as int?;
        _activeOpenedAt = orderMap['opened_at'] != null
            ? DateTime.parse(orderMap['opened_at'] as String)
            : null;
        _orderDiscountType = orderMap['discount_type'] as String?;
        _orderDiscountValue = (orderMap['discount_value'] as num?)?.toDouble() ?? 0;
        _orderDiscountNote = orderMap['discount_note'] as String?;
        final itemsRes = await _repo.getOrderItemsWithProduct(_activeOrderId!);
        for (var row in itemsRes) {
          final product = Product(
            id: (row['product_id'] as num).toInt(),
            name: row['product_name'] as String,
            price: (row['product_price'] as num).toDouble(),
            category: row['product_category'] as String,
            quantity: (row['product_quantity'] as num?)?.toDouble(),
            noServiceCharge: (row['no_service_charge'] as int? ?? 0) == 1,
          );
          _items[product.id!] = CartItem(
            product: product,
            quantity: (row['qty'] as num).toDouble(),
            printedQuantity: (row['printed_qty'] as num? ?? 0).toDouble(),
            discountAmount: (row['discount_amount'] as num? ?? 0).toDouble(),
          );
        }
      }
      // Assign logged-in waiter if not set
      if (_activeWaiterId == null && connectivity != null) {
        final role = connectivity.currentUser?['role'] ?? '';
        if (role == 'waiter') {
          final rawId = connectivity.currentUser?['id'];
          if (rawId != null) {
            _activeWaiterId = rawId is int ? rawId : int.tryParse(rawId.toString());
          }
        }
      }
      notifyListeners();
      return;
    }

    if (tableId != null) {
      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        final remoteTables = await connectivity.getRemoteData(
          '/tables/summary',
        );
        final tableData = remoteTables.firstWhere(
          (t) => t['id'] == tableId,
          orElse: () => <String, dynamic>{},
        );

        if (tableData.isNotEmpty && tableData['order_id'] != null) {
          _activeOrderId = tableData['order_id'];
          _activeWaiterId = tableData['waiter_id'];
          _activeOpenedAt = tableData['opened_at'] != null
              ? DateTime.parse(tableData['opened_at'])
              : null;

          final response = await http.get(
            Uri.parse('${connectivity.clientBaseUrl}/orders/$_activeOrderId'),
            headers: {'Authorization': 'Bearer ${connectivity.authToken}'},
          );
          if (response.statusCode == 200) {
            final orderDetail = jsonDecode(response.body);
            final List itemsList = orderDetail['items'] ?? [];
            for (var row in itemsList) {
              final product = Product(
                id: (row['product_id'] as num).toInt(),
                name: row['product_name'] as String,
                price: (row['price'] as num).toDouble(),
                category: '',
                noServiceCharge: (row['no_service_charge'] as int? ?? 0) == 1,
              );
              _items[product.id!] = CartItem(
                product: product,
                quantity: (row['qty'] as num).toDouble(),
                printedQuantity: (row['printed_qty'] as num? ?? 0).toDouble(),
              );
            }
          }
        }
      } else {
        // 1. First find which order is active for THIS table
        final activeId = await _repo.getActiveOrderIdForTable(tableId);

        if (activeId != null) {
          final orderMap = await _repo.getOpenOrderById(activeId);

          if (orderMap != null) {
            _activeOrderId = orderMap['id'] as String;
            _activeWaiterId = orderMap['waiter_id'] as int?;

            // Load order-level discount
            _orderDiscountType = orderMap['discount_type'] as String?;
            _orderDiscountValue = (orderMap['discount_value'] as num?)?.toDouble() ?? 0;
            _orderDiscountNote = orderMap['discount_note'] as String?;

            bool needsDefaultWaiterSync = false;
            if (_activeWaiterId == null) {
              _activeWaiterId = await _repo.getDefaultWaiterId();
              needsDefaultWaiterSync = _activeWaiterId != null;
            }

            _activeOpenedAt = orderMap['opened_at'] != null
                ? DateTime.parse(orderMap['opened_at'] as String)
                : null;

            final itemsRes = await _repo.getOrderItemsWithProduct(_activeOrderId!);

            for (var row in itemsRes) {
              final product = Product(
                id: (row['product_id'] as num).toInt(),
                name: row['product_name'] as String,
                price: (row['product_price'] as num).toDouble(),
                category: row['product_category'] as String,
                quantity: (row['product_quantity'] as num?)?.toDouble(),
                noServiceCharge: (row['no_service_charge'] as int? ?? 0) == 1,
              );
              _items[product.id!] = CartItem(
                product: product,
                quantity: (row['qty'] as num).toDouble(),
                printedQuantity: (row['printed_qty'] as num? ?? 0).toDouble(),
                discountAmount: (row['discount_amount'] as num? ?? 0).toDouble(),
              );
            }

            // Items endi yuklandi — faqat shu paytda header'ni sinxronlash
            // xavfsiz, aks holda totalAmount bo'sh _items'dan 0 hisoblanib,
            // grand_total bazada noto'g'ri nolga tushib qolardi.
            if (needsDefaultWaiterSync) {
              await _syncOrderHeader();
            }
          }
        }
      }
    }

    // Pre-assign the logged-in waiter so the order is immediately linked to them
    if (_activeWaiterId == null && connectivity != null) {
      final role = connectivity.currentUser?['role'] ?? '';
      if (role == 'waiter') {
        final rawId = connectivity.currentUser?['id'];
        if (rawId != null) {
          _activeWaiterId = rawId is int
              ? rawId
              : int.tryParse(rawId.toString());
        }
      }
    }

    notifyListeners();
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> confirmTableOrder(
    BuildContext context, [
    ConnectivityProvider? connectivity,
    bool showNotification = true,
  ]) async {
    // Capture providers synchronously before any await
    final tableProvider = context.read<TableProvider>();
    final waiterProvider = context.read<WaiterProvider>();
    debugPrint(
      '[confirm] orderId=$_activeOrderId orderType=$_activeOrderType items=${_items.length} unconfirmed=$hasUnconfirmedChanges',
    );
    if (_activeOrderId == null) {
      await _ensureOrderExists(connectivity, true);
      debugPrint('[confirm] after ensureOrder: orderId=$_activeOrderId');
    }
    if (_activeOrderId == null) {
      if (context.mounted) {
        final msg = _activeOrderType == 0
            ? 'Xatolik: Buyurtma ID topilmadi. Stolni qayta tanlang.'
            : 'Xatolik: Buyurtma yaratilmadi. Saboy bo\'limini qayta oching.';
        _showError(context, msg);
      }
      return;
    }
    if (!hasUnconfirmedChanges) {
      if (context.mounted) {
        _showError(
          context,
          'Yangi o\'zgarish yo\'q. Avval mahsulot qo\'shing.',
        );
      }
      return;
    }

    final List<OrderItem> itemsToPrint = [];

    for (var item in _items.values) {
      if (item.quantity != item.printedQuantity) {
        final double delta = item.quantity - item.printedQuantity;
        itemsToPrint.add(
          OrderItem(
            orderId: _activeOrderId!,
            productId: item.product.id!,
            productName: item.product.name,
            qty: delta,
            unit: item.product.unit,
            price: item.product.price,
            printedQty: item.quantity,
          ),
        );
      }
    }

    if (itemsToPrint.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Chop etiladigan mahsulot yo\'q.');
      }
      return;
    }

    int? currentDailyNo;
    try {
      currentDailyNo = await _repo.getOrderDailyNumber(_activeOrderId!);
    } catch (e) {
      debugPrint("Could not fetch daily number for confirm: $e");
    }

    final double roomCharge = _activeOrderType == 0
        ? (await calculateRoomChargeForUI(context))
        : 0;
    final double serviceFee = calculateWaiterServiceFee(context);
    final double foodTotal = totalAmount;
    final double grandTotal = foodTotal + roomCharge + serviceFee;

    // Safe lookups — providers may not be fully loaded yet when SAQLASH is pressed
    String? tableNameSafe;
    if (_activeTableId != null) {
      try {
        tableNameSafe = tableProvider.tables
            .firstWhere((t) => t.id == _activeTableId)
            .name;
      } catch (_) {}
    }
    String? waiterNameSafe;
    if (_activeWaiterId != null) {
      try {
        waiterNameSafe = waiterProvider.waiters
            .firstWhere((w) => w.id == _activeWaiterId)
            .name;
      } catch (_) {
        // Waiters list not yet loaded — use the logged-in user's name directly
        waiterNameSafe = connectivity?.currentUser?['role'] == 'waiter'
            ? connectivity!.currentUser!['name'] as String?
            : null;
      }
    }

    final populatedOrder = Order(
      id: _activeOrderId!,
      total: grandTotal,
      paymentType: 'Pending',
      createdAt: DateTime.now(),
      items: itemsToPrint,
      orderType: _activeOrderType,
      tableId: _activeTableId,
      waiterId: _activeWaiterId,
      locationId: _activeLocationId,
      dailyNumber: currentDailyNo,
      roomCharge: roomCharge,
      foodTotal: foodTotal,
      roomTotal: roomCharge,
      serviceTotal: serviceFee,
      grandTotal: grandTotal,
      tableName: tableNameSafe,
      waiterName: waiterNameSafe,
    );

    try {
      // Client mode → server prints on its own printers; otherwise print locally.
      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        final printErr = await connectivity.requestPrint(populatedOrder);
        if (printErr != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(printErr), backgroundColor: Colors.orange),
          );
        }
      } else {
        await PrintingService.printDividedOrder(order: populatedOrder);
      }

      // Update in-memory printedQuantity and clean up deleted items
      final List<int> toRemove = [];
      _items.forEach((id, item) {
        if (item.quantity == 0) {
          toRemove.add(id);
        } else {
          item.printedQuantity = item.quantity;
        }
      });

      for (var id in toRemove) {
        _items.remove(id);
      }

      // Assign the waiter to the order only now — not when the table was opened
      if (_activeWaiterId != null && _activeOrderId != null) {
        await _repo.updateOrderWaiter(_activeOrderId!, _activeWaiterId);
      }

      await _syncItems(connectivity, context);

      // Broadcast so TablesScreen refreshes even if it missed the initial broadcast
      // from _ensureOrderExists (e.g. TablesScreen was not yet subscribed then).
      if (_activeTableId != null &&
          (connectivity == null ||
              connectivity.mode != ConnectivityMode.client)) {
        WebSocketManager.instance.broadcast('tables_updated', {
          'table_id': _activeTableId!,
        });
      }

      notifyListeners();

      if (context.mounted && showNotification) {
        // No snackbar
      }
    } catch (e) {
      AppLogger.e('ConfirmOrder', 'Buyurtma tasdiqlashda xato | stol=$_activeTableId', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _ensureOrderExists([
    ConnectivityProvider? connectivity,
    bool forceCreate = false,
  ]) async {
    final tableId = _activeTableId;
    debugPrint(
      '[ensureOrder] tableId=$tableId orderType=$_activeOrderType mode=${connectivity?.mode}',
    );
    if (tableId == null && _activeOrderType == 0) {
      debugPrint('[ensureOrder] EARLY RETURN: no table + dine-in');
      return;
    }
    if (_activeOrderId != null) return;

    // Don't create order until SAQLASH is pressed (forceCreate only from confirmTableOrder)
    if (!forceCreate) {
      final anyPrinted = _items.values.any((i) => i.printedQuantity > 0);
      if (!anyPrinted) {
        debugPrint('[ensureOrder] EARLY RETURN: nothing printed yet, waiting for SAQLASH');
        return;
      }
    }

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      try {
        final response = await http.post(
          Uri.parse('${connectivity.clientBaseUrl}/orders/open'),
          body: jsonEncode({
            'table_id': tableId,
            'waiter_id': connectivity.currentUser?['id'],
            'order_type': _activeOrderType,
          }),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${connectivity.authToken}',
          },
        );
        debugPrint(
          '[ensureOrder] server status=${response.statusCode} body=${response.body}',
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _activeOrderId = data['order_id'];
          _activeOpenedAt = DateTime.now();

          await _repo.insertOrder({
            'id': _activeOrderId,
            'total': 0.0,
            'payment_type': 'Pending',
            'created_at': _activeOpenedAt!.toIso8601String(),
            'opened_at': _activeOpenedAt!.toIso8601String(),
            'order_type': _activeOrderType,
            'table_id': tableId,
            'location_id': _activeLocationId,
            'waiter_id': connectivity.currentUser?['id'],
            'status': 0,
            'daily_number': data['daily_number'],
          });

          if (tableId != null) {
            await _repo.updateTableLink(
              tableId,
              status: 1,
              activeOrderId: _activeOrderId,
            );
          }
        }
      } catch (e) {
        debugPrint('[ensureOrder] client HTTP error: $e');
      }
      return;
    }

    // Claim the order ID synchronously BEFORE any await so that concurrent calls
    // from _syncItems and _checkAutoConfirm (both fire-and-forget from addItem)
    // cannot both pass the '_activeOrderId != null' guard and create duplicate orders.
    final newOrderId = const Uuid().v4();
    _activeOrderId = newOrderId;
    _activeOpenedAt = DateTime.now();
    _isNewOrderSession = true;

    try {
      // If a waiter is logged in, use their ID; otherwise fall back to default waiter
      if (_activeWaiterId == null && connectivity != null) {
        final role = connectivity.currentUser?['role'] ?? '';
        if (role == 'waiter') {
          final rawId = connectivity.currentUser?['id'];
          if (rawId != null) {
            _activeWaiterId = rawId is int
                ? rawId
                : int.tryParse(rawId.toString());
          }
        }
      }
      _activeWaiterId ??= await _repo.getDefaultWaiterId();

      await _repo.insertOrder({
        'id': newOrderId,
        'total': 0.0,
        'payment_type': 'Pending',
        'created_at': _activeOpenedAt!.toIso8601String(),
        'opened_at': _activeOpenedAt!.toIso8601String(),
        'order_type': _activeOrderType,
        'table_id': tableId,
        'location_id': _activeLocationId,
        'waiter_id': null,
        'status': 0,
      });

      if (tableId != null) {
        await _repo.updateTableLink(tableId, status: 1, activeOrderId: newOrderId);
        WebSocketManager.instance.broadcast('tables_updated', {
          'table_id': tableId,
        });
      }

      // Assign daily number
      final dailyNo = await _getNextDailyNumber();
      await _repo.updateOrderDailyNumber(newOrderId, dailyNo);
    } catch (e) {
      // If DB operations fail, reset the in-memory state so the next call retries
      // instead of silently skipping order creation (order ID was set before awaits).
      debugPrint('[ensureOrder] DB error, resetting state: $e');
      _activeOrderId = null;
      _activeOpenedAt = null;
      _isNewOrderSession = false;
    }
  }

  Future<int> _getNextDailyNumber() => _repo.getNextDailyNumber();

  Future<void> _syncOrderHeader([BuildContext? context]) async {
    final orderId = _activeOrderId;
    if (orderId == null) return;

    double roomTotal = 0;
    double serviceTotal = 0;
    if (context != null) {
      roomTotal = await calculateRoomChargeForUI(context);
      serviceTotal = calculateWaiterServiceFee(context);
    }

    final discountAmt = orderDiscountAmount;
    final grandTotal = (totalAmount - discountAmt + roomTotal + serviceTotal).clamp(0.0, double.infinity);
    await _repo.updateOrderHeader(
      orderId,
      foodTotal: totalAmount,
      roomTotal: roomTotal,
      serviceTotal: serviceTotal,
      grandTotal: grandTotal,
      waiterId: _activeWaiterId,
      discountType: _orderDiscountType,
      discountValue: _orderDiscountValue,
      discountNote: _orderDiscountNote,
    );
  }

  // Debounce + mutex: addItem/removeItem/updateQuantity dan keladigan tez-tez
  // chaqiruvlarni birlashtiradi va parallelda ikki yozuv bo'lishini oldini oladi.
  void _scheduleSyncItems([
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 400), () {
      _syncItems(connectivity, context);
    });
  }

  Future<void> _syncItems([
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) async {
    if (_activeTableId == null && _activeOrderType == 0) return;

    // Don't write to DB until SAQLASH is pressed — items stay in memory only.
    if (connectivity?.mode != ConnectivityMode.client) {
      final anyPrinted = _items.values.any((i) => i.printedQuantity > 0);
      if (!anyPrinted) return;
    }

    // Parallelda ikki _syncItems transaction bo'lmasligi uchun
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _ensureOrderExists(connectivity);
      await _syncOrderHeader(context);

      // orderId va itemsSnapshot ni async gapdan OLDIN mahalliy o'zgaruvchiga olamiz.
      // Checkout yoki loadTableOrder _activeOrderId ni null qilib qo'ysa ham
      // bu snapshot to'g'ri qiymatni saqlaydi.
      final orderId = _activeOrderId;
      if (orderId == null) return;

      final itemsSnapshot = Map<int, CartItem>.from(_items);
      final waiterId = _activeWaiterId;

      if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
        final itemsList = itemsSnapshot.values
            .map((item) => {
                  'product_id': item.product.id,
                  'product_name': item.product.name,
                  'qty': item.quantity,
                  'unit': item.product.unit,
                  'price': item.product.price,
                  'printed_qty': item.printedQuantity,
                })
            .toList();

        await http.post(
          Uri.parse('${connectivity.clientBaseUrl}/orders/$orderId/items'),
          body: jsonEncode({'items': itemsList, 'waiter_id': waiterId}),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${connectivity.authToken}',
          },
        );
        return;
      }

      final itemRows = <Map<String, dynamic>>[];
      for (var item in itemsSnapshot.values) {
        if (item.quantity == 0 && item.printedQuantity == 0) continue;
        itemRows.add({
          'order_id': orderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'qty': item.quantity,
          'unit': item.product.unit,
          'price': item.product.price,
          'printed_qty': item.printedQuantity,
          'discount_amount': item.discountAmount,
        });
      }
      await _repo.replaceOrderItems(orderId, itemRows);
    } finally {
      _isSyncing = false;
    }
  }

  void addItem(
    Product product, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
    double quantity = 1.0,
  ]) {
    double currentInCart = _items[product.id]?.quantity ?? 0.0;
    if (product.quantity != null &&
        (currentInCart + quantity) > product.quantity!) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.insufficientStock),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_items.containsKey(product.id)) {
      _items.update(product.id!, (existing) {
        return CartItem(
          product: product,
          quantity: existing.quantity + quantity,
          printedQuantity: existing.printedQuantity,
          discountAmount: existing.discountAmount, // preserve discount
        );
      });
    } else {
      _items.putIfAbsent(
        product.id!,
        () => CartItem(product: product, quantity: quantity),
      );
    }
    _scheduleSyncItems(connectivity, context);
    notifyListeners();
    Future.microtask(() => _checkAutoConfirm(context));
  }

  void removeItem(
    int productId, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    if (_items.containsKey(productId)) {
      final item = _items[productId]!;
      if (item.printedQuantity > 0) {
        item.quantity = 0;
      } else {
        _items.remove(productId);
      }
      _scheduleSyncItems(connectivity, context);
      notifyListeners();
      Future.microtask(() => _checkAutoConfirm(context));
    }
  }

  void updateQuantity(
    int productId,
    double quantity, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    if (_items.containsKey(productId)) {
      final product = _items[productId]!.product;
      if (product.quantity != null && quantity > (product.quantity!)) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.insufficientStock),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (quantity <= 0) {
        if (_items[productId]!.printedQuantity > 0) {
          _items[productId]!.quantity = 0;
        } else {
          _items.remove(productId);
        }
      } else {
        _items[productId]!.quantity = quantity;
      }
      _scheduleSyncItems(connectivity, context);
      notifyListeners();
      Future.microtask(() => _checkAutoConfirm(context));
    }
  }

  void updateItem(
    int productId, {
    double? quantity,
    double? price,
    ConnectivityProvider? connectivity,
    BuildContext? context,
  }) {
    if (_items.containsKey(productId)) {
      final item = _items[productId]!;
      if (quantity != null) {
        if (item.product.quantity != null &&
            quantity > (item.product.quantity!)) {
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.insufficientStock),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        if (quantity <= 0) {
          if (item.printedQuantity > 0) {
            item.quantity = 0;
          } else {
            _items.remove(productId);
          }
        } else {
          item.quantity = quantity;
        }
      }

      if (price != null && _items.containsKey(productId)) {
        _items[productId]!.product = _items[productId]!.product.copyWith(
          price: price,
        );
      }

      _scheduleSyncItems(connectivity, context);
      notifyListeners();
      Future.microtask(() => _checkAutoConfirm(context));
    }
  }

  Future<void> _checkAutoConfirm(BuildContext? context) async {
    if (context == null) return;
    try {
      final connectivity = context.read<ConnectivityProvider>();
      // Waiters always use the manual SAQLASH button — never auto-confirm for them
      final role = connectivity.currentUser?['role'] ?? 'admin';
      if (role == 'waiter') return;
      final autoConfirm = context.read<AppSettingsProvider>().autoConfirmOrder;

      if (autoConfirm || !hasPermission(context, 'perm_confirm_order')) {
        await confirmTableOrder(context, connectivity, false);
      }
    } catch (e) {
      debugPrint("Auto-confirm error: $e");
    }
  }

  void setOrderDiscount(
    String type,
    double value, [
    String? note,
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    _orderDiscountType = type;
    _orderDiscountValue = value;
    _orderDiscountNote = note;
    _scheduleSyncItems(connectivity, context);
    notifyListeners();
  }

  void removeOrderDiscount([
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    _orderDiscountType = null;
    _orderDiscountValue = 0;
    _orderDiscountNote = null;
    _scheduleSyncItems(connectivity, context);
    notifyListeners();
  }

  void setItemDiscount(
    int productId,
    double amount, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    if (_items.containsKey(productId)) {
      _items[productId]!.discountAmount = amount;
      _scheduleSyncItems(connectivity, context);
      notifyListeners();
    }
  }

  void removeItemDiscount(
    int productId, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    setItemDiscount(productId, 0, connectivity, context);
  }

  void clearCart([ConnectivityProvider? connectivity, BuildContext? context]) {
    _items.clear();
    _orderDiscountType = null;
    _orderDiscountValue = 0;
    _orderDiscountNote = null;
    if (_activeOrderId != null) {
      _syncItems(connectivity, context);
    }
    notifyListeners();
  }

  // Returns orderId on success, null on failure
  Future<String?> checkout({
    required BuildContext context,
    required String paymentType,
    int orderType = 0,
    int? tableId,
    int? waiterId,
    int? locationId,
    double paidAmount = 0,
    double change = 0,
    bool shouldPrint = true,
    String? note,
  }) async {
    if (_items.isEmpty) return null;

    // ── FIX 2 & 3: Provider reads BEFORE any await (BuildContext async gap lint)
    // context.read<>() must be called synchronously before the first await.
    final int? resolvedTableId = tableId ?? _activeTableId;
    final int? resolvedLocationId = locationId ?? _activeLocationId;
    final int? resolvedWaiterId = waiterId ?? _activeWaiterId;

    String? safeTableName;
    String? safeLocationName;
    String? safeWaiterName;
    try {
      if (resolvedTableId != null) {
        safeTableName = context
            .read<TableProvider>()
            .tables
            .firstWhere((t) => t.id == resolvedTableId)
            .name;
      }
    } catch (_) {}
    try {
      if (resolvedLocationId != null) {
        safeLocationName = context
            .read<LocationProvider>()
            .locations
            .firstWhere((l) => l.id == resolvedLocationId)
            .name;
      }
    } catch (_) {}
    try {
      if (resolvedWaiterId != null) {
        safeWaiterName = context
            .read<WaiterProvider>()
            .waiters
            .firstWhere((w) => w.id == resolvedWaiterId)
            .name;
      }
    } catch (_) {}
    final double preServiceFee = calculateWaiterServiceFee(context);
    // shift_id ni sinxron o'qib olish (async gap oldidan)
    int? activeShiftId;
    try {
      activeShiftId = context.read<ShiftProvider>().activeShift?.id;
    } catch (_) {}

    // Automatic kitchen printing for unconfirmed changes during checkout
    if (hasUnconfirmedChanges) {
      try {
        await confirmTableOrder(context, null, false);
      } catch (e) {
        debugPrint("Automatic kitchen print error: $e");
      }
    }

    final orderId = _activeOrderId ?? const Uuid().v4();
    final currentTableId = _activeTableId; // Capture locally
    final List<OrderItem> orderItems = [];

    try {
      // ── daily_number ni buyurtma yozishdan OLDIN olamiz ────────────────────
      // (tranzaksiya ichida chaqirilsa sqflite_common_ffi da deadlock bo'ladi)
      int? preDailyNo;
      if (_activeOrderId != null) {
        preDailyNo = await _repo.getOrderDailyNumber(orderId);
      }
      preDailyNo ??= await _getNextDailyNumber();

      // Buyurtma qatorlarini tayyorlash (bundle JSON biznes logikasi bilan)
      for (var item in _items.values) {
        String? bundleJson;
        if (item.product.isSet && item.product.bundleItems != null) {
          bundleJson = jsonEncode(
            item.product.bundleItems!.map((bi) => bi.toMap()).toList(),
          );
        }
        orderItems.add(OrderItem(
          orderId: orderId,
          productId: item.product.id!,
          qty: item.quantity,
          unit: item.product.unit,
          price: item.product.price,
          productName: item.product.name,
          bundleItemsJson: bundleJson,
          discountAmount: item.discountAmount,
        ));
      }

      final cleanedNote =
          (note != null && note.trim().isNotEmpty) ? note.trim() : null;

      // To'lovni yakunlash (xona narxi hisobi + yozuv) — bitta tranzaksiyada
      final totals = await _repo.commitCheckout(
        orderId: orderId,
        isExistingOrder: _activeOrderId != null,
        currentTableId: currentTableId,
        resolvedTableId: resolvedTableId,
        resolvedLocationId: resolvedLocationId,
        resolvedWaiterId: resolvedWaiterId,
        orderType: orderType,
        paymentType: paymentType,
        paidAmount: paidAmount,
        change: change,
        preDailyNo: preDailyNo,
        activeShiftId: activeShiftId,
        cleanedNote: cleanedNote,
        discountType: _orderDiscountType,
        discountValue: _orderDiscountValue,
        discountNote: _orderDiscountNote,
        foodTotal: totalAmount,
        discountAmount: orderDiscountAmount,
        serviceFee: preServiceFee,
        totalForServiceCharge: totalForServiceCharge,
        openedAt: _activeOpenedAt,
        items: orderItems,
      );

      final double currentRoomCharge = totals['roomCharge']!;
      final double currentServiceFee = totals['serviceFee']!;
      final double currentFoodTotal = totals['foodTotal']!;
      final double currentGrandTotal = totals['grandTotal']!;

      final populatedOrder = Order(
        id: orderId,
        total: currentGrandTotal,
        paymentType: paymentType,
        createdAt: DateTime.now(),
        items: orderItems,
        orderType: orderType,
        tableId: resolvedTableId,
        waiterId: resolvedWaiterId,
        locationId: resolvedLocationId,
        openedAt: _activeOpenedAt,
        closedAt: DateTime.now(),
        roomCharge: currentRoomCharge,
        foodTotal: currentFoodTotal,
        roomTotal: currentRoomCharge,
        serviceTotal: currentServiceFee,
        grandTotal: currentGrandTotal,
        dailyNumber: preDailyNo,
        tableName: safeTableName,
        locationName: safeLocationName,
        waiterName: safeWaiterName,
        paidAmount: paidAmount,
        change: change,
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        discountType: _orderDiscountType,
        discountValue: _orderDiscountValue,
        discountNote: _orderDiscountNote,
      );

      final connectivity = context.read<ConnectivityProvider>();
      final isClient = connectivity.mode == ConnectivityMode.client;

      // 1. Process Order Payment/Inventory (Server or Local)
      if (isClient) {
        final paySuccess = await connectivity.payOrder(
          orderId,
          {
            'payment_type': paymentType,
            'paid_amount': paidAmount,
            'change': change,
            'note': note,
          },
          roomCharge: currentRoomCharge,
          serviceFee: currentServiceFee,
          foodTotal: currentFoodTotal,
          grandTotal: currentGrandTotal,
          waiterId: resolvedWaiterId,
        );

        if (!paySuccess) {
          debugPrint("Server payOrder failed");
          return null;
        }
      } else {
        // Local or Server mode
        if (context.mounted &&
            context.read<AppSettingsProvider>().enableInventory) {
          // Full inventory system (recipes, ingredients, audit log)
          try {
            await InventoryService.instance.processOrderPaid(populatedOrder);
          } catch (e) {
            debugPrint("Inventory processing error: $e");
          }
        } else {
          // Basic stock tracking: always decrement products.quantity in DB
          await _repo.decrementProductStock(orderItems);
        }
      }

      // 2. Notify other connected devices (server/local mode)
      if (!isClient) {
        WebSocketManager.instance.broadcast('tables_updated', {
          'table_id': ?resolvedTableId,
        });
      }

      // 3. Reload products — DB is now correct in both paths
      if (context.mounted) {
        context.read<ProductProvider>().loadProducts(
          connectivity: connectivity,
        );
      }

      AppLogger.i('Checkout', 'To\'lov qabul qilindi | buyurtma=${populatedOrder.id} | jami=${currentGrandTotal.toStringAsFixed(0)} | to\'lov=$paymentType | stol=$safeTableName');

      _lastPrintError = null;
      if (shouldPrint) {
        try {
          await PrintingService.printReceipt(order: populatedOrder);
          AppLogger.i('Checkout', 'Chek chop etildi | buyurtma=${populatedOrder.id}');
        } catch (printError) {
          AppLogger.e('Checkout', 'Chek chop etishda xato | buyurtma=${populatedOrder.id}', printError);
          _lastPrintError = 'Printer xatoligi: $printError';
          notifyListeners();
        }
      }

      _activeTableId = null;
      _activeOrderId = null;
      _activeWaiterId = null;
      _activeLocationId = null;
      _activeOpenedAt = null;
      _items.clear();
      _orderDiscountType = null;
      _orderDiscountValue = 0;
      _orderDiscountNote = null;
      notifyListeners();

      // ShiftProvider live summaryni yangilash
      if (context.mounted) {
        try {
          context.read<ShiftProvider>().refresh();
        } catch (_) {}
      }

      return orderId;
    } catch (e, st) {
      AppLogger.e('Checkout', 'To\'lov jarayonida kritik xato', e, st);
      return null;
    }
  }

  Future<double> calculateRoomChargeForUI(BuildContext context) async {
    final orderId = _activeOrderId;
    final currentTableId = _activeTableId;
    // If neither order nor table is known, no charge possible
    if (orderId == null && currentTableId == null) return 0;
    try {
      // Include current table by id too (same as checkout) in case active_order_id
      // is not yet written to DB for a brand-new order.
      final linkedTables = await _repo.getLinkedTables(
        orderId: orderId,
        tableId: currentTableId,
      );

      double totalCharge = 0;
      final now = DateTime.now();

      for (var tableMap in linkedTables) {
        final pricingType = tableMap['pricing_type'] as int? ?? 0;
        final hourlyRate = (tableMap['hourly_rate'] as num? ?? 0).toDouble();
        final fixedAmount = (tableMap['fixed_amount'] as num? ?? 0).toDouble();
        final servicePercentage = (tableMap['service_percentage'] as num? ?? 0)
            .toDouble();

        if (pricingType == 1) {
          final openedAt = _activeOpenedAt ?? now;
          final duration = now.difference(openedAt);
          final hours = duration.inMinutes / 60.0;
          totalCharge += hours * hourlyRate;
        } else if (pricingType == 2) {
          totalCharge += fixedAmount;
        } else if (pricingType == 3) {
          totalCharge += (totalForServiceCharge * servicePercentage / 100);
        }
      }
      return totalCharge;
    } catch (e) {
      debugPrint("Error calculating room charge: $e");
    }
    return 0;
  }

  /// Stol obyektidan sinxron tarzda xona narxini hisoblaydi (DB query yo'q).
  /// CartPanel, payment dialog va temp receipt uchun ishlatiladi.
  double calculateRoomChargeFromTable(table_model.TableModel? table) {
    if (table == null) return 0;
    switch (table.pricingType) {
      case 1: // soatli
        if (_activeOpenedAt == null) return 0;
        final hours =
            DateTime.now().difference(_activeOpenedAt!).inMinutes / 60.0;
        return (hours * table.hourlyRate).roundToDouble();
      case 2: // fiksal
        return table.fixedAmount;
      case 3: // xizmat foizi
        return (totalForServiceCharge * table.servicePercentage / 100)
            .roundToDouble();
      default:
        return 0;
    }
  }

  double calculateWaiterServiceFee(BuildContext context) {
    if (_activeWaiterId == null) return 0;
    try {
      final waiterProvider = context.read<WaiterProvider>();
      final waiter = waiterProvider.waiters.firstWhere(
        (w) => w.id == _activeWaiterId,
      );

      // If waiter is "Kassa", service fee is 0
      if (waiter.name.toLowerCase() == 'kassa') return 0;

      if (waiter.type == 1) {
        // percentage
        return (totalForServiceCharge * waiter.value / 100).roundToDouble();
      } else {
        // fixed
        return waiter.value;
      }
    } catch (e) {
      debugPrint("Error calculating waiter service fee: $e");
    }
    return 0;
  }

  /// Ofisiant buyurtmadan chiqishda itemlarni DBga saqlash uchun
  Future<void> persistCartState([
    ConnectivityProvider? connectivity,
    TableProvider? tableProvider,
  ]) async {
    if (_items.isEmpty && _activeOrderId == null) return;

    final bool anyPrinted = _items.values.any((item) => item.printedQuantity > 0);

    // Nothing was confirmed via SAQLASH — discard and free the table
    if (!anyPrinted) {
      if (_activeOrderId != null) await cancelOrder(connectivity);
      _items.clear();
      notifyListeners();
      tableProvider?.loadTables();
      return;
    }

    await _ensureOrderExists(connectivity);
    await _syncItems(connectivity);

    // Guarantee the table is marked occupied in DB regardless of any earlier
    // async race between fire-and-forget _syncItems calls and PopScope.
    if (_activeTableId != null &&
        _activeOrderId != null &&
        (connectivity == null ||
            connectivity.mode != ConnectivityMode.client)) {
      try {
        await _repo.updateTableLink(
          _activeTableId!,
          status: 1,
          activeOrderId: _activeOrderId,
        );
        WebSocketManager.instance.broadcast('tables_updated', {
          'table_id': _activeTableId,
        });
      } catch (e) {
        debugPrint('[persistCartState] table status update error: $e');
      }
    }
  }

  Future<bool> cancelOrder([ConnectivityProvider? connectivity]) async {
    if (_activeOrderId == null) return false;

    try {
      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        // Client mode: send cancel request to server
        final response = await http.delete(
          Uri.parse(
            '${connectivity.clientBaseUrl}/orders/$_activeOrderId/cancel',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${connectivity.authToken}',
          },
        );

        if (response.statusCode != 200) {
          debugPrint("Failed to cancel order on server");
          return false;
        }
      } else {
        // Local mode: delete from local database
        await _repo.cancelOrderLocal(_activeOrderId!);
        WebSocketManager.instance.broadcast('tables_updated');
      }

      // Clear cart state
      _items.clear();
      _activeTableId = null;
      _activeOrderId = null;
      _activeWaiterId = null;
      _activeLocationId = null;
      _activeOpenedAt = null;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint("Cancel order error: $e");
      return false;
    }
  }

  Future<void> discardUnconfirmedChanges([
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) async {
    if (_activeOrderId == null) return;

    final bool anyPrinted = _items.values.any(
      (item) => item.printedQuantity > 0,
    );

    if (_isNewOrderSession && !anyPrinted) {
      // If nothing was ever printed AND it was a new order session, just cancel the whole order to free the table
      await cancelOrder(connectivity);
    } else if (hasUnconfirmedChanges) {
      // Revert unconfirmed changes (revert qty to printed_qty)
      final List<int> toRemove = [];
      _items.forEach((id, item) {
        if (item.printedQuantity == 0) {
          toRemove.add(id);
        } else {
          item.quantity = item.printedQuantity;
        }
      });

      for (var id in toRemove) {
        _items.remove(id);
      }

      await _syncItems(connectivity, context);
      notifyListeners();
    }
  }

  /// Mark all current items as "preserved" so PopScope doesn't cancel the order
  /// when navigating via pushReplacement (e.g. after moving a table).
  void markOrderPreserved() {
    _isNewOrderSession = false;
    _items.forEach((_, item) {
      if (item.quantity > 0) {
        item.printedQuantity = item.quantity;
      }
    });
    notifyListeners();
  }

  Future<bool> moveToTable(
    int newTableId,
    int newLocationId, [
    ConnectivityProvider? connectivity,
  ]) async {
    if (_activeOrderId == null) return false;

    try {
      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        // Client mode: send move request to server
        final response = await http.put(
          Uri.parse(
            '${connectivity.clientBaseUrl}/orders/$_activeOrderId/move',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${connectivity.authToken}',
          },
          body: jsonEncode({
            'table_id': newTableId,
            'location_id': newLocationId,
          }),
        );

        if (response.statusCode != 200) {
          debugPrint("Failed to move order on server");
          return false;
        }
      } else {
        // Local mode: update in local database
        await _repo.moveOrderLocal(
          orderId: _activeOrderId!,
          newTableId: newTableId,
          newLocationId: newLocationId,
          oldTableId: _activeTableId,
        );
      }

      // Audit: Stol o'zgarganda
      if (_activeOrderId != null) {
        AuditService.instance.logAction(
          action: 'change_table',
          entity: 'order',
          entityId: _activeOrderId!,
          before: {
            'table_id': _activeTableId,
            'location_id': _activeLocationId,
          },
          after: {'table_id': newTableId, 'location_id': newLocationId},
        );
      }

      // Notify other connected devices
      WebSocketManager.instance.broadcast('tables_updated');

      // Update cart state
      _activeTableId = newTableId;
      _activeLocationId = newLocationId;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint("Move order error: $e");
      return false;
    }
  }

  Future<bool> mergeTable(
    int sourceTableId,
    int targetTableId, [
    ConnectivityProvider? connectivity,
  ]) async {
    try {
      // Client mode: send to server
      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        final success = await connectivity.postRemoteData('/tables/merge', {
          'source_table_id': sourceTableId,
          'target_table_id': targetTableId,
        });
        if (success) {
          if (_activeTableId == sourceTableId ||
              _activeTableId == targetTableId) {
            await loadTableOrder(
              _activeTableId,
              _activeLocationId,
              connectivity,
            );
          }
        }
        return success;
      }

      final finalOrderId = await _repo.mergeTablesLocal(
        sourceTableId,
        targetTableId,
      );
      if (finalOrderId == null) return false; // Birlashtirishga narsa yo'q

      // Audit log
      AuditService.instance.logAction(
        action: 'merge_table',
        entity: 'order',
        entityId: finalOrderId,
        after: {
          'source_table_id': sourceTableId,
          'target_table_id': targetTableId,
        },
      );

      // Notify other connected devices
      WebSocketManager.instance.broadcast('tables_updated');

      // If we are currently on specialized table, reload its order
      if (_activeTableId == sourceTableId || _activeTableId == targetTableId) {
        await loadTableOrder(_activeTableId, _activeLocationId, connectivity);
      }

      return true;
    } catch (e) {
      debugPrint("Merge table error: $e");
      return false;
    }
  }
}

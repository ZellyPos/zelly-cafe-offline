import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../core/database_helper.dart';
import '../core/app_strings.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../core/printing_service.dart';
import 'table_provider.dart';
import 'location_provider.dart';
import 'waiter_provider.dart';
import 'connectivity_provider.dart';
import '../core/services/audit_service.dart';

class CartItem {
  final Product product;
  double quantity;
  double printedQuantity;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    this.printedQuantity = 0.0,
  });

  double get total => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  String? _lastPrintError;

  // Restaurant Mode state
  int? _activeTableId;
  String? _activeOrderId;
  int? _activeWaiterId;
  int? _activeLocationId;
  DateTime? _activeOpenedAt;

  Map<int, CartItem> get items => _items;
  String? get lastPrintError => _lastPrintError;
  int? get activeTableId => _activeTableId;
  int? get activeWaiterId => _activeWaiterId;
  String? get activeOrderId => _activeOrderId;
  DateTime? get activeOpenedAt => _activeOpenedAt;

  bool get hasUnconfirmedChanges {
    return _items.values.any((item) => item.quantity > item.printedQuantity);
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

    if (role == 'waiter') {
      // 1. If we have permissions in currentUser map (from API login), use them
      final userPerms = connectivity.currentUser?['permissions'];
      if (userPerms != null && userPerms is List) {
        return userPerms.contains(permissionId);
      }

      // 2. Fallback to checking _activeWaiterId if currentUser perms are missing (local mode fallback)
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

  void setWaiter(int? waiterId, [BuildContext? context]) {
    final oldWaiterId = _activeWaiterId;
    _activeWaiterId = waiterId;
    _syncOrderHeader(context);

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
  ]) async {
    _activeTableId = tableId;
    _activeLocationId = locationId;
    _items.clear();
    _activeOrderId = null;
    _activeWaiterId = null;
    _activeOpenedAt = null;

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
                id: row['product_id'] as int,
                name: row['product_name'] as String,
                price: (row['price'] as num).toDouble(),
                category: '',
              );
              _items[product.id!] = CartItem(
                product: product,
                quantity: (row['qty'] as num).toDouble(),
              );
            }
          }
        }
      } else {
        final db = await DatabaseHelper.instance.database;

        // 1. First find which order is active for THIS table
        final tableRes = await db.query(
          'tables',
          columns: ['active_order_id'],
          where: 'id = ?',
          whereArgs: [tableId],
        );
        final String? activeId = tableRes.isNotEmpty
            ? tableRes.first['active_order_id'] as String?
            : null;

        if (activeId != null) {
          final orderRes = await db.query(
            'orders',
            where: 'id = ? AND status = 0',
            whereArgs: [activeId],
          );

          if (orderRes.isNotEmpty) {
            final orderMap = orderRes.first;
            _activeOrderId = orderMap['id'] as String;
            _activeWaiterId = orderMap['waiter_id'] as int?;

            if (_activeWaiterId == null) {
              _activeWaiterId = await DatabaseHelper.instance
                  .getDefaultWaiterId();
              if (_activeWaiterId != null) {
                await _syncOrderHeader();
              }
            }

            _activeOpenedAt = orderMap['opened_at'] != null
                ? DateTime.parse(orderMap['opened_at'] as String)
                : null;

            final itemsRes = await db.rawQuery(
              '''
              SELECT oi.*, p.name as product_name, p.price as product_price, p.category as product_category, p.quantity as product_quantity
              FROM order_items oi
              JOIN products p ON oi.product_id = p.id
              WHERE oi.order_id = ?
            ''',
              [_activeOrderId],
            );

            for (var row in itemsRes) {
              final product = Product(
                id: row['product_id'] as int,
                name: row['product_name'] as String,
                price: (row['product_price'] as num).toDouble(),
                category: row['product_category'] as String,
                quantity: (row['product_quantity'] as num?)?.toDouble(),
              );
              _items[product.id!] = CartItem(
                product: product,
                quantity: (row['qty'] as num).toDouble(),
                printedQuantity: (row['printed_qty'] as num? ?? 0).toDouble(),
              );
            }
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> confirmTableOrder(
    BuildContext context, [
    ConnectivityProvider? connectivity,
  ]) async {
    if (_activeOrderId == null) return;
    if (!hasUnconfirmedChanges) return;

    final List<OrderItem> itemsToPrint = [];

    for (var item in _items.values) {
      if (item.quantity > item.printedQuantity) {
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

    if (itemsToPrint.isEmpty) return;

    final populatedOrder = Order(
      id: _activeOrderId!,
      total: totalAmount,
      paymentType: 'Pending',
      createdAt: DateTime.now(),
      items: itemsToPrint,
      orderType: 0,
      tableId: _activeTableId,
      waiterId: _activeWaiterId,
      locationId: _activeLocationId,
      tableName: _activeTableId != null
          ? context
                .read<TableProvider>()
                .tables
                .firstWhere((t) => t.id == _activeTableId)
                .name
          : null,
      waiterName: _activeWaiterId != null
          ? context
                .read<WaiterProvider>()
                .waiters
                .firstWhere((w) => w.id == _activeWaiterId)
                .name
          : null,
    );

    try {
      await PrintingService.printDividedOrder(order: populatedOrder);

      // Update in-memory printedQuantity
      for (var item in _items.values) {
        item.printedQuantity = item.quantity;
      }

      // Update database printed_qty
      await _syncItems(connectivity, context);
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buyurtma oshxonaga yuborildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printer xatoligi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _ensureOrderExists([ConnectivityProvider? connectivity]) async {
    final tableId = _activeTableId;
    if (tableId == null) return;
    if (_activeOrderId != null) return;

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final response = await http.post(
        Uri.parse('${connectivity.clientBaseUrl}/orders/open'),
        body: jsonEncode({
          'table_id': tableId,
          'waiter_id': connectivity.currentUser?['id'],
          'order_type': 0,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${connectivity.authToken}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _activeOrderId = data['order_id'];
        _activeOpenedAt = DateTime.now();
      }
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final newOrderId = const Uuid().v4();
    _activeOrderId = newOrderId;
    _activeOpenedAt = DateTime.now();

    _activeWaiterId ??= await DatabaseHelper.instance.getDefaultWaiterId();

    await db.insert('orders', {
      'id': newOrderId,
      'total': 0.0,
      'payment_type': 'Pending',
      'created_at': _activeOpenedAt!.toIso8601String(),
      'opened_at': _activeOpenedAt!.toIso8601String(),
      'order_type': 0,
      'table_id': tableId,
      'location_id': _activeLocationId,
      'waiter_id': _activeWaiterId,
      'status': 0,
    });

    await db.update(
      'tables',
      {'status': 1, 'active_order_id': newOrderId},
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }

  Future<void> _syncOrderHeader([BuildContext? context]) async {
    final orderId = _activeOrderId;
    if (orderId == null) return;
    final db = await DatabaseHelper.instance.database;

    double roomTotal = 0;
    double serviceTotal = 0;
    if (context != null) {
      roomTotal = await calculateRoomChargeForUI(context);
      serviceTotal = calculateWaiterServiceFee(context);
    }

    await db.update(
      'orders',
      {
        'total': totalAmount + roomTotal + serviceTotal,
        'waiter_id': _activeWaiterId,
        'food_total': totalAmount,
        'room_total': roomTotal,
        'service_total': serviceTotal,
        'grand_total': totalAmount + roomTotal + serviceTotal,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> _syncItems([
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) async {
    if (_activeTableId == null) return;
    await _ensureOrderExists(connectivity);
    await _syncOrderHeader(context);

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      if (_activeOrderId == null) return;

      final itemsList = _items.values
          .map(
            (item) => {
              'product_id': item.product.id,
              'product_name': item.product.name,
              'qty': item.quantity,
              'unit': item.product.unit,
              'price': item.product.price,
            },
          )
          .toList();

      await http.post(
        Uri.parse('${connectivity.clientBaseUrl}/orders/$_activeOrderId/items'),
        body: jsonEncode({'items': itemsList}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${connectivity.authToken}',
        },
      );
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [_activeOrderId],
      );

      for (var item in _items.values) {
        await txn.insert('order_items', {
          'order_id': _activeOrderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'qty': item.quantity,
          'unit': item.product.unit,
          'price': item.product.price,
          'printed_qty': item.printedQuantity,
        });
      }

      await txn.update(
        'orders',
        {
          'total': totalAmount,
          'food_total': totalAmount,
          'grand_total':
              totalAmount, // Initial, will be updated with room/waiter
        },
        where: 'id = ?',
        whereArgs: [_activeOrderId],
      );
    });
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
      _items.update(
        product.id!,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + quantity,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id!,
        () => CartItem(product: product, quantity: quantity),
      );
    }
    _syncItems(connectivity, context);
    notifyListeners();
  }

  void removeItem(
    int productId, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    _items.remove(productId);
    _syncItems(connectivity, context);
    notifyListeners();
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
        _items.remove(productId);
      } else {
        _items[productId]!.quantity = quantity;
      }
      _syncItems(connectivity, context);
      notifyListeners();
    }
  }

  void clearCart([ConnectivityProvider? connectivity, BuildContext? context]) {
    _items.clear();
    if (_activeOrderId != null) {
      _syncItems(connectivity, context);
    }
    notifyListeners();
  }

  Future<bool> checkout({
    required BuildContext context,
    required String paymentType,
    int orderType = 0,
    int? tableId,
    int? waiterId,
    int? locationId,
    double paidAmount = 0,
    double change = 0,
    bool shouldPrint = true,
  }) async {
    if (_items.isEmpty) return false;

    final orderId = _activeOrderId ?? const Uuid().v4();
    final currentTableId = _activeTableId; // Capture locally
    final List<OrderItem> orderItems = [];

    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        double roomCharge = 0;
        double totalRoomCharge = 0;
        DateTime now = DateTime.now();

        // 1. Find all tables linked to this order to sum their charges
        final allLinkedTablesRes = await txn.query(
          'tables',
          where: currentTableId != null
              ? 'active_order_id = ? OR id = ?'
              : 'active_order_id = ?',
          whereArgs: currentTableId != null
              ? [orderId, currentTableId]
              : [orderId],
        );

        for (var tableMap in allLinkedTablesRes) {
          final int pricingType = tableMap['pricing_type'] as int? ?? 0;
          final double hourlyRate = (tableMap['hourly_rate'] as num? ?? 0)
              .toDouble();
          final double fixedAmount = (tableMap['fixed_amount'] as num? ?? 0)
              .toDouble();
          final double servicePercentage =
              (tableMap['service_percentage'] as num? ?? 0).toDouble();

          if (pricingType == 1) {
            final openedAt = _activeOpenedAt ?? now;
            final duration = now.difference(openedAt);
            final hours = duration.inMinutes / 60.0;
            totalRoomCharge += hours * hourlyRate;
          } else if (pricingType == 2) {
            totalRoomCharge += fixedAmount;
          } else if (pricingType == 3) {
            totalRoomCharge += (totalAmount * servicePercentage / 100);
          }
        }
        roomCharge = totalRoomCharge;

        final double serviceFee = calculateWaiterServiceFee(context);
        final double foodTotal = totalAmount;
        final double grandTotal = foodTotal + roomCharge + serviceFee;

        if (_activeOrderId != null) {
          await txn.update(
            'orders',
            {
              'total': grandTotal,
              'payment_type': paymentType,
              'status': 1,
              'waiter_id': waiterId ?? _activeWaiterId,
              'closed_at': now.toIso8601String(),
              'room_charge': roomCharge,
              'paid_amount': paidAmount,
              'receipt_change': change,
              'food_total': foodTotal,
              'room_total': roomCharge,
              'service_total': serviceFee,
              'grand_total': grandTotal,
            },
            where: 'id = ?',
            whereArgs: [orderId],
          );
        } else {
          final order = Order(
            id: orderId,
            total: grandTotal,
            paymentType: paymentType,
            createdAt: now,
            orderType: orderType,
            tableId: tableId,
            waiterId: waiterId ?? _activeWaiterId,
            locationId: locationId,
            status: 1,
            paidAmount: paidAmount,
            change: change,
            foodTotal: foodTotal,
            roomTotal: roomCharge,
            serviceTotal: serviceFee,
            grandTotal: grandTotal,
            openedAt: now,
            closedAt: now,
          );
          await txn.insert('orders', order.toMap());
        }

        if (_activeOrderId != null) {
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderId],
          );
        }

        for (var item in _items.values) {
          String? bundleJson;
          if (item.product.isSet && item.product.bundleItems != null) {
            bundleJson = jsonEncode(
              item.product.bundleItems!.map((bi) => bi.toMap()).toList(),
            );
          }

          final orderItem = OrderItem(
            orderId: orderId,
            productId: item.product.id!,
            qty: item.quantity,
            unit: item.product.unit,
            price: item.product.price,
            productName: item.product.name,
            bundleItemsJson: bundleJson,
          );
          await txn.insert('order_items', orderItem.toMap());
          orderItems.add(orderItem);

          // Inventory Management: Decrement product quantity if it exists
          if (item.product.quantity != null) {
            await txn.rawUpdate(
              'UPDATE products SET quantity = quantity - ? WHERE id = ?',
              [item.quantity, item.product.id],
            );
          }
        }

        if (tableId != null || _activeTableId != null) {
          await txn.update(
            'tables',
            {'status': 0, 'active_order_id': null},
            where: 'active_order_id = ?',
            whereArgs: [orderId],
          );
        }
      });

      final double currentRoomCharge = orderType == 0
          ? (await calculateRoomChargeForUI(context))
          : 0;
      final double currentServiceFee = calculateWaiterServiceFee(context);
      final double currentFoodTotal = totalAmount;
      final double currentGrandTotal =
          currentFoodTotal + currentRoomCharge + currentServiceFee;

      final populatedOrder = Order(
        id: orderId,
        total: currentGrandTotal,
        paymentType: paymentType,
        createdAt: DateTime.now(),
        items: orderItems,
        orderType: orderType,
        tableId: tableId ?? _activeTableId,
        waiterId: waiterId ?? _activeWaiterId,
        locationId: locationId ?? _activeLocationId,
        openedAt: _activeOpenedAt,
        closedAt: DateTime.now(),
        roomCharge: currentRoomCharge,
        foodTotal: currentFoodTotal,
        roomTotal: currentRoomCharge,
        serviceTotal: currentServiceFee,
        grandTotal: currentGrandTotal,
        tableName: (tableId ?? _activeTableId) != null
            ? context
                  .read<TableProvider>()
                  .tables
                  .firstWhere((t) => t.id == (tableId ?? _activeTableId))
                  .name
            : null,
        locationName: (locationId ?? _activeLocationId) != null
            ? context
                  .read<LocationProvider>()
                  .locations
                  .firstWhere((l) => l.id == (locationId ?? _activeLocationId))
                  .name
            : null,
        waiterName: (waiterId ?? _activeWaiterId) != null
            ? context
                  .read<WaiterProvider>()
                  .waiters
                  .firstWhere((w) => w.id == (waiterId ?? _activeWaiterId))
                  .name
            : null,
        paidAmount: paidAmount,
        change: change,
      );

      _lastPrintError = null;
      if (shouldPrint) {
        try {
          await PrintingService.printReceipt(order: populatedOrder);
        } catch (printError) {
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
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Checkout error: $e");
      return false;
    }
  }

  Future<double> calculateRoomChargeForUI(BuildContext context) async {
    final orderId = _activeOrderId;
    if (orderId == null) return 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final linkedTables = await db.query(
        'tables',
        where: 'active_order_id = ?',
        whereArgs: [orderId],
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

  Future<bool> cancelOrder([ConnectivityProvider? connectivity]) async {
    if (_activeOrderId == null) return false;

    try {
      final oldOrderId = _activeOrderId;
      if (connectivity != null &&
          connectivity.mode == ConnectivityMode.client) {
        // Client mode: send cancel request to server
        final response = await http.delete(
          Uri.parse('${connectivity.clientBaseUrl}/orders/$_activeOrderId'),
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
        final db = await DatabaseHelper.instance.database;
        await db.transaction((txn) async {
          // Delete order items
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [_activeOrderId],
          );

          // Delete order
          await txn.delete(
            'orders',
            where: 'id = ?',
            whereArgs: [_activeOrderId],
          );

          // Reset tables linked to this order
          await txn.update(
            'tables',
            {'status': 0, 'active_order_id': null},
            where: 'active_order_id = ?',
            whereArgs: [_activeOrderId],
          );
        });
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
        final db = await DatabaseHelper.instance.database;
        await db.transaction((txn) async {
          // Update order with new table
          await txn.update(
            'orders',
            {'table_id': newTableId, 'location_id': newLocationId},
            where: 'id = ?',
            whereArgs: [_activeOrderId],
          );

          // OLD TABLE: handle multi-table cleanup
          // If this was the ONLY table for this order, we'd clear it.
          // But to be safe and simple for "Move", we clear current table and set new one.
          if (_activeTableId != null) {
            await txn.update(
              'tables',
              {'status': 0, 'active_order_id': null},
              where: 'id = ?',
              whereArgs: [_activeTableId],
            );
          }

          // NEW TABLE: occupy
          await txn.update(
            'tables',
            {'status': 1, 'active_order_id': _activeOrderId},
            where: 'id = ?',
            whereArgs: [newTableId],
          );
        });
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
      final db = await DatabaseHelper.instance.database;

      // 1. Get source and target table info
      final sourceTableRes = await db.query(
        'tables',
        where: 'id = ?',
        whereArgs: [sourceTableId],
      );
      final targetTableRes = await db.query(
        'tables',
        where: 'id = ?',
        whereArgs: [targetTableId],
      );

      if (sourceTableRes.isEmpty || targetTableRes.isEmpty) return false;

      final String? sourceOrderId =
          sourceTableRes.first['active_order_id'] as String?;
      final String? targetOrderId =
          targetTableRes.first['active_order_id'] as String?;

      if (sourceOrderId == null && targetOrderId == null) {
        return false; // Both empty? Nothing to merge.
      }

      await db.transaction((txn) async {
        String finalOrderId;

        if (targetOrderId != null) {
          finalOrderId = targetOrderId;
          if (sourceOrderId != null && sourceOrderId != targetOrderId) {
            // TRANSFER Items from source to target
            final sourceItems = await txn.query(
              'order_items',
              where: 'order_id = ?',
              whereArgs: [sourceOrderId],
            );
            for (var item in sourceItems) {
              // Check if same product exists in target
              final existing = await txn.query(
                'order_items',
                where: 'order_id = ? AND product_id = ?',
                whereArgs: [finalOrderId, item['product_id']],
              );

              if (existing.isNotEmpty) {
                await txn.rawUpdate(
                  'UPDATE order_items SET qty = qty + ? WHERE id = ?',
                  [item['qty'], existing.first['id']],
                );
              } else {
                await txn.insert('order_items', {
                  'order_id': finalOrderId,
                  'product_id': item['product_id'],
                  'qty': item['qty'],
                  'price': item['price'],
                  'bundle_items_json': item['bundle_items_json'],
                });
              }
            }
            // Delete source order
            await txn.delete(
              'order_items',
              where: 'order_id = ?',
              whereArgs: [sourceOrderId],
            );
            await txn.delete(
              'orders',
              where: 'id = ?',
              whereArgs: [sourceOrderId],
            );
          }
        } else {
          // target is empty, source has order. Just link target to source order.
          finalOrderId = sourceOrderId!;
        }

        // Link both tables to the same order ID
        await txn.update(
          'tables',
          {'status': 1, 'active_order_id': finalOrderId},
          where: 'id = ? OR id = ?',
          whereArgs: [sourceTableId, targetTableId],
        );

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
      });

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

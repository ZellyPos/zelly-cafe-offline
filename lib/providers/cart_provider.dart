import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../core/database_helper.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../core/printing_service.dart';
import 'table_provider.dart';
import 'location_provider.dart';
import 'waiter_provider.dart';
import 'connectivity_provider.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

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
  String? get activeOrderId => _activeOrderId;
  int? get activeWaiterId => _activeWaiterId;
  DateTime? get activeOpenedAt => _activeOpenedAt;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.total;
    });
    return total;
  }

  void setWaiter(int? waiterId, [BuildContext? context]) {
    _activeWaiterId = waiterId;
    _syncOrderHeader(context);
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
                quantity: row['qty'] as int,
              );
            }
          }
        }
      } else {
        final db = await DatabaseHelper.instance.database;
        final orderRes = await db.query(
          'orders',
          where: 'table_id = ? AND status = 0',
          whereArgs: [tableId],
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
            SELECT oi.*, p.name as product_name, p.price as product_price, p.category as product_category
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
            );
            _items[product.id!] = CartItem(
              product: product,
              quantity: row['qty'] as int,
            );
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> _ensureOrderExists([ConnectivityProvider? connectivity]) async {
    if (_activeTableId == null) return;
    if (_activeOrderId != null) return;

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final response = await http.post(
        Uri.parse('${connectivity.clientBaseUrl}/orders/open'),
        body: jsonEncode({
          'table_id': _activeTableId,
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
    _activeOrderId = const Uuid().v4();
    _activeOpenedAt = DateTime.now();

    if (_activeWaiterId == null) {
      _activeWaiterId = await DatabaseHelper.instance.getDefaultWaiterId();
    }

    await db.insert('orders', {
      'id': _activeOrderId,
      'total': 0.0,
      'payment_type': 'Pending',
      'created_at': _activeOpenedAt!.toIso8601String(),
      'opened_at': _activeOpenedAt!.toIso8601String(),
      'order_type': 0,
      'table_id': _activeTableId,
      'location_id': _activeLocationId,
      'waiter_id': _activeWaiterId,
      'status': 0,
    });

    await db.update(
      'tables',
      {'status': 1},
      where: 'id = ?',
      whereArgs: [_activeTableId],
    );
  }

  Future<void> _syncOrderHeader([BuildContext? context]) async {
    if (_activeOrderId == null) return;
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
      whereArgs: [_activeOrderId],
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
              'qty': item.quantity,
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
          'qty': item.quantity,
          'price': item.product.price,
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
  ]) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id!,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(product.id!, () => CartItem(product: product));
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
    int quantity, [
    ConnectivityProvider? connectivity,
    BuildContext? context,
  ]) {
    if (_items.containsKey(productId)) {
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
  }) async {
    if (_items.isEmpty) return false;

    final orderId = _activeOrderId ?? const Uuid().v4();
    final List<OrderItem> orderItems = [];

    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        double roomCharge = 0;
        DateTime now = DateTime.now();

        if (_activeTableId != null) {
          final table = context.read<TableProvider>().tables.firstWhere(
            (t) => t.id == _activeTableId,
          );

          if (table.pricingType == 1) {
            final openedAt = _activeOpenedAt ?? now;
            final duration = now.difference(openedAt);
            final minutes = duration.inMinutes;

            const int step = 30;
            final roundedMinutes = ((minutes + step - 1) ~/ step) * step;
            final hours = roundedMinutes / 60.0;
            roomCharge = hours * table.hourlyRate;
          } else if (table.pricingType == 2) {
            roomCharge = table.fixedAmount;
          }
        }

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
          final orderItem = OrderItem(
            orderId: orderId,
            productId: item.product.id!,
            qty: item.quantity,
            price: item.product.price,
            productName: item.product.name,
          );
          await txn.insert('order_items', orderItem.toMap());
          orderItems.add(orderItem);
        }

        if (tableId != null || _activeTableId != null) {
          await txn.update(
            'tables',
            {'status': 0},
            where: 'id = ?',
            whereArgs: [tableId ?? _activeTableId],
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
      try {
        await PrintingService.printReceipt(order: populatedOrder);
      } catch (printError) {
        _lastPrintError = 'Printer xatoligi: $printError';
        notifyListeners();
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
    if (_activeTableId == null) return 0;
    try {
      final table = context.read<TableProvider>().tables.firstWhere(
        (t) => t.id == _activeTableId,
      );
      if (table.pricingType == 1) {
        final openedAt = _activeOpenedAt ?? DateTime.now();
        final duration = DateTime.now().difference(openedAt);
        final minutes = duration.inMinutes;
        const int step = 30;
        final roundedMinutes = ((minutes + step - 1) ~/ step) * step;
        final hours = roundedMinutes / 60.0;
        return hours * table.hourlyRate;
      } else if (table.pricingType == 2) {
        return table.fixedAmount;
      }
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
        return (totalAmount * waiter.value / 100).roundToDouble();
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

          // Reset table status to available
          if (_activeTableId != null) {
            await txn.update(
              'tables',
              {'status': 0},
              where: 'id = ?',
              whereArgs: [_activeTableId],
            );
          }
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
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../services/inventory_service.dart';
import '../printing_service.dart';
import 'websocket_manager.dart';

class ApiServer {
  static HttpServer? _server;
  static final _router = Router();


  static Future<String?> start(int port) async {
    _setupRoutes();

    try {
      _server = await io.serve(
        Pipeline().addMiddleware(logRequests()).addHandler(_router.call),
        InternetAddress.anyIPv4,
        port,
      );
      print('Server running on ${_server!.address.address}:${_server!.port}');
      return _server!.address.address;
    } catch (e) {
      print('Error starting server: $e');
      return null;
    }
  }

  static void stop() {
    _server?.close();
    _server = null;
  }

  static Future<Directory> _getImagesDir() async {
    final appDocDir = await getApplicationSupportDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'product_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  static void _setupRoutes() {
    // 0. WebSocket real-time channel
    _router.get(
      '/ws',
      webSocketHandler((WebSocketChannel channel, String? protocol) {
        WebSocketManager.instance.addClient(channel);
      }),
    );

    // 1. Auth
    _router.post('/auth/login', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final pin = payload['pin'] as String?;

      if (pin == null || pin.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'PIN kodi kiritilmadi'}),
        );
      }

      final db = await DatabaseHelper.instance.database;

      // Waiters login
      final waiters = await db.query(
        'waiters',
        where: 'pin_code = ? AND is_active = 1',
        whereArgs: [pin],
      );

      if (waiters.isNotEmpty) {
        final waiter = waiters.first;
        final permsStr = waiter['permissions']?.toString() ?? '';
        final permsList = permsStr.isEmpty ? [] : permsStr.split(',');

        return Response.ok(
          jsonEncode({
            'token': 'waiter-token-${waiter['id']}',
            'user': {
              'id': waiter['id'],
              'name': waiter['name'],
              'role': 'waiter',
              'permissions': permsList,
            },
          }),
        );
      }

      // Fallback for Admin (Local/Server mode admin access)
      final users = await db.query(
        'users',
        where: 'pin = ? AND is_active = 1',
        whereArgs: [pin],
      );

      if (users.isNotEmpty) {
        final user = users.first;
        final userPermsStr = user['permissions']?.toString() ?? '';
        return Response.ok(
          jsonEncode({
            'token': 'admin-token-${user['id']}',
            'user': {
              'id': user['id'],
              'name': user['name'],
              'role': user['role'], // admin or cashier
              'permissions': userPermsStr,
            },
          }),
        );
      }

      return Response.forbidden(
        jsonEncode({'error': 'PIN kod noto‘g‘ri yoki xodim faol emas'}),
      );
    });

    // /auth/me — token bo'yicha joriy foydalanuvchi ma'lumotlarini qaytaradi
    _router.get('/auth/me', (Request request) async {
      try {
        final authHeader = request.headers['Authorization'] ?? '';
        final db = await DatabaseHelper.instance.database;

        if (authHeader.startsWith('Bearer waiter-token-')) {
          final id = int.tryParse(
            authHeader.replaceFirst('Bearer waiter-token-', ''),
          );
          if (id == null) return Response.forbidden(jsonEncode({'error': 'Token noto\'g\'ri'}));

          final rows = await db.query('waiters', where: 'id = ? AND is_active = 1', whereArgs: [id]);
          if (rows.isEmpty) return Response.forbidden(jsonEncode({'error': 'Foydalanuvchi topilmadi'}));

          final w = rows.first;
          final permsStr = w['permissions']?.toString() ?? '';
          return Response.ok(jsonEncode({
            'id': w['id'],
            'name': w['name'],
            'role': 'waiter',
            'permissions': permsStr.isEmpty ? [] : permsStr.split(','),
          }), headers: {'Content-Type': 'application/json'});
        }

        if (authHeader.startsWith('Bearer admin-token-') ||
            authHeader.startsWith('Bearer user-token-')) {
          final idStr = authHeader
              .replaceFirst('Bearer admin-token-', '')
              .replaceFirst('Bearer user-token-', '');
          final id = int.tryParse(idStr);
          if (id == null) return Response.forbidden(jsonEncode({'error': 'Token noto\'g\'ri'}));

          final rows = await db.query('users', where: 'id = ? AND is_active = 1', whereArgs: [id]);
          if (rows.isEmpty) return Response.forbidden(jsonEncode({'error': 'Foydalanuvchi topilmadi'}));

          final u = rows.first;
          final permsStr = u['permissions']?.toString() ?? '';
          return Response.ok(jsonEncode({
            'id': u['id'],
            'name': u['name'],
            'role': u['role'],
            'permissions': permsStr.isEmpty ? [] : permsStr.split(','),
          }), headers: {'Content-Type': 'application/json'});
        }

        return Response.forbidden(jsonEncode({'error': 'Token topilmadi'}));
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': '$e'}));
      }
    });

    // 2. Locations & Tables
    _router.get('/locations', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('locations');
      return Response.ok(jsonEncode(data));
    });

    _router.get('/tables', (Request request) async {
      final locId = request.url.queryParameters['location_id'];
      final db = await DatabaseHelper.instance.database;

      final List<Map<String, dynamic>> tables;
      if (locId != null) {
        tables = await db.query(
          'tables',
          where: 'location_id = ?',
          whereArgs: [locId],
        );
      } else {
        tables = await db.query('tables');
      }
      return Response.ok(jsonEncode(tables));
    });

    _router.post('/tables', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'tables',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('tables', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.delete('/tables/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('tables', where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.post('/locations', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'locations',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('locations', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.delete('/locations/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('locations', where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.get('/tables/summary', (Request request) async {
      final db = await DatabaseHelper.instance.database;
      // Get tables with their active orders if any
      final summary = await db.rawQuery('''
        SELECT
          t.id, t.location_id, t.name, t.status, t.pricing_type, 
          t.hourly_rate, t.fixed_amount, t.active_order_id,
          t.x, t.y, t.width, t.height, t.shape, t.service_percentage,
          l.name as location_name,
          o.id as order_id,
          o.total as order_total,
          o.waiter_id,
          o.bill_requested,
          w.name as waiter_name,
          o.opened_at
        FROM tables t
        LEFT JOIN locations l ON t.location_id = l.id
        LEFT JOIN orders o ON t.active_order_id = o.id AND o.status = 0
        LEFT JOIN waiters w ON o.waiter_id = w.id
      ''');
      
      print('API [GET] /tables/summary: Loaded ${summary.length} tables');
      if (summary.isNotEmpty) {
        print('First table summary example: ID=${summary.first['id']}, '
              'Status=${summary.first['status']}, '
              'ActiveOrderID=${summary.first['active_order_id']}, '
              'JoinOrderID=${summary.first['order_id']}');
      }
      
      return Response.ok(jsonEncode(summary));
    });

    // 3. Products
    _router.get('/products', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('products');
      // Strip full paths from image_path for remote clients
      final processedData = data.map((item) {
        final newItem = Map<String, dynamic>.from(item);
        if (newItem['image_path'] != null) {
          newItem['image_path'] = p.basename(newItem['image_path'] as String);
        }
        return newItem;
      }).toList();
      return Response.ok(jsonEncode(processedData));
    });

    _router.get('/categories', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('categories');
      return Response.ok(jsonEncode(data));
    });

    // Printers — mobil ilova uchun
    _router.get('/printers', (Request request) async {
      try {
        final db = await DatabaseHelper.instance.database;
        final printers = await db.query('printers');
        final result = printers.map((p) {
          final row = Map<String, dynamic>.from(p);
          // category_ids: JSON array → List<int>
          final catRaw = row['category_ids']?.toString() ?? '';
          List<int> catIds = [];
          if (catRaw.isNotEmpty) {
            try {
              catIds = List<int>.from(jsonDecode(catRaw));
            } catch (_) {
              catIds = catRaw
                  .split(',')
                  .map((e) => int.tryParse(e.trim()) ?? 0)
                  .where((e) => e != 0)
                  .toList();
            }
          }
          row['category_ids'] = catIds;
          // is_main: int → bool
          row['is_main'] = (row['is_main'] as int? ?? 0) == 1;
          return row;
        }).toList();
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': '$e'}));
      }
    });

    // Settings — mobil ilova uchun kerakli sozlamalar
    _router.get('/settings', (Request request) async {
      try {
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query('settings');

        // Faqat mobil ilovaga kerakli kalitlar
        const allowedKeys = {
          'restaurant_name',
          'receipt_restaurant_name',
          'receipt_branch_name',
          'receipt_phone',
          'receipt_address',
          'receipt_footer_message',
          'receipt_show_room_charges',
          'receipt_layout_type',
          'receipt_cut_paper',
          'receipt_feed_lines',
          'receipt_horizontal_margin',
          'kitchen_header_text',
          'kitchen_font_large',
          'kitchen_group_by_category',
          'kitchen_show_order_number',
          'kitchen_show_table',
          'kitchen_show_waiter',
          'kitchen_cut_paper',
          'kitchen_feed_lines',
          'auto_confirm_order',
          'enable_inventory',
        };

        final Map<String, dynamic> result = {};
        for (final row in rows) {
          final key = row['key'] as String;
          if (allowedKeys.contains(key)) {
            result[key] = row['value'];
          }
        }
        return Response.ok(
          jsonEncode(result),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': '$e'}));
      }
    });

    // 4. Waiters
    _router.get('/waiters', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('waiters');
      final mapped = data.map((waiter) {
        final newWaiter = Map<String, dynamic>.from(waiter);
        final permsStr = newWaiter['permissions']?.toString() ?? '';
        newWaiter['permissions'] = permsStr.isEmpty ? [] : permsStr.split(',');
        return newWaiter;
      }).toList();
      return Response.ok(jsonEncode(mapped));
    });

    _router.post('/waiters', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'waiters',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('waiters', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.delete('/waiters/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('waiters', where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // 5. Users
    _router.get('/users', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('users');
      return Response.ok(jsonEncode(data));
    });

    _router.post('/users', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'users',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('users', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.delete('/users/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // 6. Expenses & Categories
    _router.get('/expense_categories', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('expense_categories');
      return Response.ok(jsonEncode(data));
    });

    _router.post('/expense_categories', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'expense_categories',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('expense_categories', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.get('/expenses', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('expenses');
      return Response.ok(jsonEncode(data));
    });

    _router.post('/expenses', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'expenses',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('expenses', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.delete('/expenses/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // 7. Customers
    _router.get('/customers', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('customers');
      return Response.ok(jsonEncode(data));
    });

    _router.post('/customers', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;
      if (payload['id'] != null) {
        await db.update(
          'customers',
          payload,
          where: 'id = ?',
          whereArgs: [payload['id']],
        );
      } else {
        await db.insert('customers', payload);
      }
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.delete('/customers/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('customers', where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.get('/transactions', (Request request) async {
      final customerId = request.url.queryParameters['customer_id'];
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'transactions',
        where: customerId != null ? 'customer_id = ?' : null,
        whereArgs: customerId != null ? [customerId] : null,
        orderBy: 'created_at DESC',
      );
      return Response.ok(jsonEncode(results));
    });

    _router.post('/transactions', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        await txn.insert('transactions', payload);

        if (payload['customer_id'] != null) {
          final customerRes = await txn.query(
            'customers',
            where: 'id = ?',
            whereArgs: [payload['customer_id']],
            limit: 1,
          );

          if (customerRes.isNotEmpty) {
            final customer = Customer.fromMap(customerRes.first);
            double newDebt = customer.debt;
            double newCredit = customer.credit;
            final double amount = (payload['amount'] as num).toDouble();

            if (payload['type'] == 'outlay') {
              newDebt += amount;
            } else if (payload['type'] == 'payment') {
              if (newDebt >= amount) {
                newDebt -= amount;
              } else {
                double remainder = amount - newDebt;
                newDebt = 0;
                newCredit += remainder;
              }
            }

            await txn.update(
              'customers',
              {'debt': newDebt, 'credit': newCredit},
              where: 'id = ?',
              whereArgs: [payload['customer_id']],
            );
          }
        }
      });

      return Response.ok(jsonEncode({'success': true}));
    });

    _router.post('/orders/open', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final tableId = payload['table_id'] as int?;

        // Enforce waiter_id from token
        final authHeader = request.headers['Authorization'] ?? '';
        int waiterId = 1;
        if (authHeader.startsWith('Bearer waiter-token-')) {
          waiterId =
              int.tryParse(authHeader.replaceFirst('Bearer waiter-token-', '')) ??
              1;
        }

        final orderType = payload['order_type'] as int? ?? 0;
        final db = await DatabaseHelper.instance.database;

        // Check if table already has open order (only for dine-in)
        if (tableId != null) {
          final existing = await db.query(
            'orders',
            where: 'table_id = ? AND status = 0',
            whereArgs: [tableId],
          );

          if (existing.isNotEmpty) {
            final orderId = existing.first['id'];
            final dailyNo = existing.first['daily_number'];
            return Response.ok(jsonEncode({
              'order_id': orderId,
              'daily_number': dailyNo,
              'status': 'existing'
            }));
          }
        }

        final orderId = DateTime.now().millisecondsSinceEpoch.toString();

        final dayStart = await DatabaseHelper.instance.getDayStartTime();

        int nextNo = 1;
        final res = await db.rawQuery(
          'SELECT MAX(daily_number) as max_no FROM orders WHERE created_at >= ?',
          [dayStart.toIso8601String()],
        );
        if (res.isNotEmpty && res.first['max_no'] != null) {
          nextNo = (res.first['max_no'] as int) + 1;
        }

        await db.transaction((txn) async {
          await txn.insert('orders', {
            'id': orderId,
            'total': 0.0,
            'payment_type': 'Pending',
            'created_at': DateTime.now().toIso8601String(),
            'order_type': orderType,
            'table_id': tableId,
            'waiter_id': waiterId,
            'status': 0,
            'opened_at': DateTime.now().toIso8601String(),
            'daily_number': nextNo,
          });

          if (tableId != null) {
            await txn.update(
              'tables',
              {'status': 1, 'active_order_id': orderId},
              where: 'id = ?',
              whereArgs: [tableId],
            );
          }
        });

        WebSocketManager.instance.broadcast('tables_updated', {
          'table_id': ?tableId,
        });

        return Response.ok(jsonEncode({
          'order_id': orderId,
          'daily_number': nextNo
        }));
      } catch (e, st) {
        debugPrint('[orders/open] ERROR: $e\n$st');
        return Response.internalServerError(body: 'orders/open error: $e');
      }
    });

    _router.get('/orders/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      final orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id.toString()],
        limit: 1,
      );
      if (orders.isEmpty) return Response.notFound('Order not found');

      final items = await db.rawQuery(
        '''
        SELECT oi.*, p.name as product_name, p.no_service_charge, p.category as category_id
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
      ''',
        [id.toString()],
      );

      var order = Map<String, dynamic>.from(orders.first);
      order['items'] = items;
      return Response.ok(jsonEncode(order));
    });

    _router.post('/orders/<id>/items', (Request request, String id) async {
      final payload = jsonDecode(await request.readAsString());
      final items = payload['items'] as List;

      final db = await DatabaseHelper.instance.database;

      // Permission check: Get order and verify waiter_id
      final orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (orders.isEmpty) {
        return Response.notFound('Order not found');
      }

      final order = orders.first;
      final orderWaiterId = order['waiter_id'] as int?;

      // Extract waiter ID from token
      final authHeader = request.headers['Authorization'] ?? '';
      int? currentWaiterId;
      bool isAdmin = false;

      if (authHeader.startsWith('Bearer waiter-token-')) {
        currentWaiterId = int.tryParse(
          authHeader.replaceFirst('Bearer waiter-token-', ''),
        );
      } else if (authHeader.startsWith('Bearer admin-token-')) {
        isAdmin = true;
      }

      // Check permission: only order owner or admin can modify
      if (!isAdmin && orderWaiterId != currentWaiterId) {
        return Response.forbidden(
          jsonEncode({
            'error': "Bu stol sizga biriktirilmagan. Tahrirlash mumkin emas.",
          }),
        );
      }

      // Preserve existing printed_qty — never allow it to decrease (race condition guard)
      final existingItems = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      final Map<int, double> existingPrintedQty = {
        for (var row in existingItems)
          (row['product_id'] as int): (row['printed_qty'] as num?)?.toDouble() ?? 0.0,
      };

      await db.transaction((txn) async {
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);

        double totalAmount = 0;
        double totalForServiceCharge = 0;

        for (var item in items) {
          final double price = (item['price'] as num).toDouble();
          final double qty = (item['qty'] as num).toDouble();
          final int productId = item['product_id'] as int;
          final String? productName = item['product_name'] as String?;

          totalAmount += price * qty;

          final prodRes = await txn.query(
            'products',
            columns: ['no_service_charge'],
            where: 'id = ?',
            whereArgs: [productId],
          );
          bool noServiceCharge = false;
          if (prodRes.isNotEmpty) {
            noServiceCharge = (prodRes.first['no_service_charge'] as int? ?? 0) == 1;
          }

          if (!noServiceCharge) {
            totalForServiceCharge += price * qty;
          }

          final double newPrintedQty = (item['printed_qty'] as num?)?.toDouble() ?? 0.0;
          // Never decrease printed_qty — use the higher value to avoid race condition
          final double safePrintedQty = newPrintedQty > (existingPrintedQty[productId] ?? 0.0)
              ? newPrintedQty
              : (existingPrintedQty[productId] ?? 0.0);

          await txn.insert('order_items', {
            'order_id': id,
            'product_id': productId,
            'product_name': productName,
            'qty': qty,
            'price': price,
            'printed_qty': safePrintedQty,
          });
        }

        // Calculate Charges
        double roomCharge = 0;
        final orderData = orders.first;
        final int? tableId = orderData['table_id'] as int?;
        final int? orderType = orderData['order_type'] as int?;

        if (orderType == 0 && tableId != null) {
          // Dine-in: Calculate room charge from linked tables
          final List<Map<String, dynamic>> linkedTables = await txn.query(
            'tables',
            where: 'active_order_id = ? OR id = ?',
            whereArgs: [id, tableId],
          );

          double totalRoomCharge = 0;
          final DateTime now = DateTime.now();
          final DateTime openedAt = DateTime.tryParse(orderData['opened_at']?.toString() ?? '') ?? now;

          for (var tableMap in linkedTables) {
            final int pricingType = tableMap['pricing_type'] as int? ?? 0;
            final double hourlyRate = (tableMap['hourly_rate'] as num? ?? 0).toDouble();
            final double fixedAmount = (tableMap['fixed_amount'] as num? ?? 0).toDouble();
            final double servicePercentage = (tableMap['service_percentage'] as num? ?? 0).toDouble();

            if (pricingType == 1) {
              final duration = now.difference(openedAt);
              final hours = duration.inMinutes / 60.0;
              totalRoomCharge += hours * hourlyRate;
            } else if (pricingType == 2) {
              totalRoomCharge += fixedAmount;
            } else if (pricingType == 3) {
              totalRoomCharge += (totalForServiceCharge * servicePercentage / 100);
            }
          }
          roomCharge = totalRoomCharge;
        }

        // Waiter Service Fee
        double serviceFee = 0;
        final int? waiterId = orderData['waiter_id'] as int?;
        if (waiterId != null) {
          final waiterRes = await txn.query('waiters', where: 'id = ?', whereArgs: [waiterId]);
          if (waiterRes.isNotEmpty) {
            final waiter = waiterRes.first;
            final String waiterName = waiter['name']?.toString() ?? '';
            final int waiterType = waiter['type'] as int? ?? 0;
            final double waiterValue = (waiter['value'] as num? ?? 0).toDouble();

            if (waiterName.toLowerCase() != 'kassa') {
              if (waiterType == 1) { // percentage
                serviceFee = (totalForServiceCharge * waiterValue / 100).roundToDouble();
              } else { // fixed
                serviceFee = waiterValue;
              }
            }
          }
        }

        final double grandTotal = totalAmount + roomCharge + serviceFee;

        await txn.update(
          'orders',
          {
            'total': grandTotal,
            'food_total': totalAmount,
            'room_charge': roomCharge,
            'room_total': roomCharge,
            'service_total': serviceFee,
            'grand_total': grandTotal,
            'waiter_id': payload['waiter_id'] ?? order['waiter_id'],
          },
          where: 'id = ?',
          whereArgs: [id.toString()],
        );
        print('API [POST] /orders/$id/items: Order total updated to $grandTotal');
      });

      WebSocketManager.instance.broadcast('order_updated', {'order_id': id});

      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // Move order to another table
    _router.put('/orders/<id>/move', (Request request, String id) async {
      final payload = jsonDecode(await request.readAsString());
      final newTableId = payload['table_id'] as int?;
      final newLocationId = payload['location_id'] as int?;

      if (newTableId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'table_id required'}),
        );
      }

      final db = await DatabaseHelper.instance.database;

      final orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (orders.isEmpty) return Response.notFound('Order not found');

      final oldTableId = orders.first['table_id'] as int?;

      await db.transaction((txn) async {
        // Update order
        final updateData = <String, dynamic>{'table_id': newTableId};
        if (newLocationId != null) updateData['location_id'] = newLocationId;
        await txn.update(
          'orders',
          updateData,
          where: 'id = ?',
          whereArgs: [id.toString()],
        );

        // Free old table
        if (oldTableId != null) {
          await txn.update(
            'tables',
            {'status': 0, 'active_order_id': null},
            where: 'id = ?',
            whereArgs: [oldTableId],
          );
        }

        // Occupy new table
        await txn.update(
          'tables',
          {'status': 1, 'active_order_id': id},
          where: 'id = ?',
          whereArgs: [newTableId],
        );
      });

      WebSocketManager.instance.broadcast('tables_updated');

      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // Merge two tables' orders
    _router.post('/tables/merge', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final sourceTableId = payload['source_table_id'] as int?;
      final targetTableId = payload['target_table_id'] as int?;

      if (sourceTableId == null || targetTableId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'source_table_id and target_table_id required'}),
        );
      }

      final db = await DatabaseHelper.instance.database;

      final sourceRes = await db.query(
        'tables',
        where: 'id = ?',
        whereArgs: [sourceTableId],
      );
      final targetRes = await db.query(
        'tables',
        where: 'id = ?',
        whereArgs: [targetTableId],
      );

      if (sourceRes.isEmpty || targetRes.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Table not found'}));
      }

      final String? sourceOrderId =
          sourceRes.first['active_order_id'] as String?;
      final String? targetOrderId =
          targetRes.first['active_order_id'] as String?;

      if (sourceOrderId == null && targetOrderId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Both tables are empty'}),
        );
      }

      await db.transaction((txn) async {
        String finalOrderId;

        if (targetOrderId != null) {
          finalOrderId = targetOrderId;
          if (sourceOrderId != null && sourceOrderId != targetOrderId) {
            final sourceItems = await txn.query(
              'order_items',
              where: 'order_id = ?',
              whereArgs: [sourceOrderId],
            );
            for (var item in sourceItems) {
              final existing = await txn.query(
                'order_items',
                where: 'order_id = ? AND product_id = ?',
                whereArgs: [finalOrderId, item['product_id']],
              );
              if (existing.isNotEmpty) {
                final srcPrintedQty = item['printed_qty'] ?? item['qty'];
                await txn.rawUpdate(
                  'UPDATE order_items SET qty = qty + ?, printed_qty = printed_qty + ? WHERE id = ?',
                  [item['qty'], srcPrintedQty, existing.first['id']],
                );
              } else {
                await txn.insert('order_items', {
                  'order_id': finalOrderId,
                  'product_id': item['product_id'],
                  'qty': item['qty'],
                  'price': item['price'],
                  'printed_qty': item['printed_qty'] ?? item['qty'],
                });
              }
            }
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
          finalOrderId = sourceOrderId!;
        }

        await txn.update(
          'tables',
          {'status': 1, 'active_order_id': finalOrderId},
          where: 'id = ? OR id = ?',
          whereArgs: [sourceTableId, targetTableId],
        );
      });

      return Response.ok(jsonEncode({'status': 'success'}));
    });

    _router.post('/orders/<id>/pay', (Request request, String id) async {
      final payload = jsonDecode(await request.readAsString());
      final db = await DatabaseHelper.instance.database;

      // Get order data
      final orders = await db.query('orders', where: 'id = ?', whereArgs: [id], limit: 1);
      if (orders.isEmpty) return Response.notFound('Order not found');

      final orderData = Map<String, dynamic>.from(orders.first);
      final itemRows = await db.rawQuery(
        '''
        SELECT oi.*, p.quantity, p.track_type, p.is_set, p.image_path, p.no_service_charge, p.unit, p.name as product_name
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
        ''',
        [id],
      );
      
      final List<OrderItem> orderItems = itemRows.map((row) => OrderItem.fromMap(row, productName: row['product_name'] as String? ?? '')).toList();
      final orderObj = Order.fromMap(orderData, items: orderItems);

      await db.transaction((txn) async {
        // Update order status and payment info
        await txn.update(
          'orders',
          {
            'status': 1, // Paid
            'payment_type': payload['payment_type'] ?? 'Cash',
            'paid_amount': (payload['paid_amount'] as num?)?.toDouble() ?? (payload['grand_total'] as num?)?.toDouble() ?? orderObj.total,
            'receipt_change': (payload['change'] as num?)?.toDouble() ?? 0.0,
            'closed_at': DateTime.now().toIso8601String(),
            'note': payload['note'],
            // Updates from client-calculated values
            'room_charge': (payload['room_charge'] as num?)?.toDouble() ?? orderObj.roomCharge,
            'room_total': (payload['room_charge'] as num?)?.toDouble() ?? orderObj.roomTotal,
            'service_total': (payload['service_total'] as num?)?.toDouble() ?? orderObj.serviceTotal,
            'food_total': (payload['food_total'] as num?)?.toDouble() ?? orderObj.foodTotal,
            'total': (payload['grand_total'] as num?)?.toDouble() ?? orderObj.total,
            'grand_total': (payload['grand_total'] as num?)?.toDouble() ?? orderObj.total,
            'waiter_id': payload['waiter_id'] ?? orderObj.waiterId,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        // If it was a table order, clear the table
        if (orderObj.tableId != null) {
          await txn.update(
            'tables',
            {'status': 0, 'active_order_id': null},
            where: 'id = ?',
            whereArgs: [orderObj.tableId],
          );
        }

        // --- CRITICAL: Process Inventory Deduction on Server ---
        await InventoryService.instance.processOrderPaid(orderObj, txn);
      });

      WebSocketManager.instance.broadcast('tables_updated');

      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // Cancel empty order
    _router.delete('/orders/<id>/cancel', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;

      // Get order
      final orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (orders.isEmpty) {
        return Response.notFound('Order not found');
      }

      final order = orders.first;
      final orderWaiterId = order['waiter_id'] as int?;
      final tableId = order['table_id'] as int?;

      // Extract waiter ID from token
      final authHeader = request.headers['Authorization'] ?? '';
      int? currentWaiterId;
      bool isAdmin = false;

      if (authHeader.startsWith('Bearer waiter-token-')) {
        currentWaiterId = int.tryParse(
          authHeader.replaceFirst('Bearer waiter-token-', ''),
        );
      } else if (authHeader.startsWith('Bearer admin-token-')) {
        isAdmin = true;
      }

      // Check permission: only order owner or admin can cancel
      if (!isAdmin && orderWaiterId != currentWaiterId) {
        return Response.forbidden(
          jsonEncode({'error': "Bu buyurtma sizga tegishli emas"}),
        );
      }

      // Allow cancelling with items if admin or cashier (if check passed above)
      // Original logic only allowed empty orders.

      // Delete order and free table
      await db.transaction((txn) async {
        await txn.delete('orders', where: 'id = ?', whereArgs: [id.toString()]);
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id.toString()]);

        if (tableId != null) {
          final count = await txn.update(
            'tables',
            {'status': 0, 'active_order_id': null},
            where: 'id = ?',
            whereArgs: [tableId],
          );
          debugPrint('API [DELETE] /orders/$id/cancel: Table #$tableId detached. Affected: $count');
        }
      });

      WebSocketManager.instance.broadcast('tables_updated', {
        'table_id': ?tableId,
      });

      return Response.ok(jsonEncode({'status': 'success'}));
    });
    // 5. Reports View (for Telegram WebApp)
    _router.get('/reports/view', (Request request) async {
      return Response.ok(
        _mobileReportHtml(),
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    });

    // 6. Image Sync
    _router.post('/upload/image', (Request request) async {
      final List<int> bytes = await request
          .read()
          .expand((chunk) => chunk)
          .toList();
      final imagesDir = await _getImagesDir();

      // Simple file name with timestamp
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}.jpg"; // Assuming jpg or handle mime
      final file = File(p.join(imagesDir.path, fileName));
      await file.writeAsBytes(bytes);

      return Response.ok(jsonEncode({'fileName': fileName}));
    });

    _router.get('/uploads/<name>', (Request request, String name) async {
      final imagesDir = await _getImagesDir();
      final file = File(p.join(imagesDir.path, name));

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String contentType = 'image/jpeg';
        if (name.endsWith('.png')) contentType = 'image/png';
        if (name.endsWith('.webp')) contentType = 'image/webp';

        return Response.ok(bytes, headers: {'Content-Type': contentType});
      }
      return Response.notFound('Image not found');
    });

    // Remote print job — client devices POST here so server prints on its printers
    _router.post('/print_job', (Request request) async {
      try {
        final body = await request.readAsString();
        final Map<String, dynamic> payload =
            Map<String, dynamic>.from(jsonDecode(body) as Map);
        final order = Order.fromPrintPayload(payload);

        // §8 — buyurtma tasdiqlanganda tayyor mahsulot qoldig'i chegiriladi.
        // Client qurilmada baza yo'q, shuning uchun tekshiruv shu yerda.
        // Qoldiq yetmasa chek chop etilmaydi va 409 qaytadi.
        if (await _inventoryEnabled()) {
          try {
            await InventoryService.instance.consumeOnConfirm(
              order.id,
              order.items
                  .map((i) => (productId: i.productId, qty: i.qty.toDouble()))
                  .toList(),
            );
          } on InsufficientStockException catch (e) {
            return Response(409,
                body: jsonEncode({'error': e.message, 'insufficient': true}),
                headers: {'Content-Type': 'application/json'});
          }
        }

        await PrintingService.printDividedOrder(order: order);
        return Response.ok(jsonEncode({'ok': true}),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        debugPrint('[print_job] Error: $e');
        return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}));
      }
    });

    // Bill requested — client devices POST here to mark order as bill_requested
    _router.post('/orders/<id>/bill_requested', (Request request, String id) async {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'orders',
          {
            'bill_requested': 1,
            'bill_requested_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        WebSocketManager.instance.broadcast('tables_updated', {});
        return Response.ok(jsonEncode({'ok': true}),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}));
      }
    });

    // ── Report API endpoints (client devices fetch from server) ─────────────

    // Telegram Mini App uchun server tomonida hisoblangan kun chegaralari
    _router.get('/reports/periods', (Request request) async {
      try {
        final dayStart = await DatabaseHelper.instance.getDayStartTime();
        final todayEnd   = dayStart.add(const Duration(days: 1));
        final yesterdayS = dayStart.subtract(const Duration(days: 1));
        final weekStart  = dayStart.subtract(const Duration(days: 6));
        final monthStart = DateTime(dayStart.year, dayStart.month, 1,
            dayStart.hour, dayStart.minute);
        final prevMonthS = DateTime(dayStart.year, dayStart.month - 1, 1,
            dayStart.hour, dayStart.minute);
        final prevMonthE = DateTime(dayStart.year, dayStart.month, 1,
            dayStart.hour, dayStart.minute);

        return Response.ok(
          jsonEncode({
            'today':     [dayStart.toIso8601String(),  todayEnd.toIso8601String()],
            'yesterday': [yesterdayS.toIso8601String(), dayStart.toIso8601String()],
            'week':      [weekStart.toIso8601String(),  todayEnd.toIso8601String()],
            'month':     [monthStart.toIso8601String(), todayEnd.toIso8601String()],
            'prevmonth': [prevMonthS.toIso8601String(), prevMonthE.toIso8601String()],
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': '$e'}));
      }
    });

    // Smena ro'yxati — Telegram Mini App shift selektor uchun
    _router.get('/reports/shifts', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final limit = int.tryParse(q['limit'] ?? '') ?? 20;
        final db = await DatabaseHelper.instance.database;
        final rows = await db.rawQuery('''
          SELECT s.id, s.opened_at, s.closed_at, s.status,
                 s.opening_cash, s.counted_cash,
                 u1.name as opened_by_name,
                 u2.name as closed_by_name,
                 COUNT(o.id) as order_count,
                 COALESCE(SUM(o.grand_total), 0) as total_sales
          FROM shifts s
          LEFT JOIN users u1 ON s.opened_by = u1.id
          LEFT JOIN users u2 ON s.closed_by = u2.id
          LEFT JOIN orders o ON o.shift_id = s.id AND o.status = 1
          GROUP BY s.id
          ORDER BY s.opened_at DESC
          LIMIT ?
        ''', [limit]);
        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/hourly', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ?? DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day + 1).toIso8601String();
        final shiftId = q['shift_id'] != null ? int.tryParse(q['shift_id']!) : null;
        final db = await DatabaseHelper.instance.database;
        final String hWhere;
        final List<dynamic> hArgs;
        if (shiftId != null) {
          hWhere = 'status = 1 AND shift_id = ?';
          hArgs  = [shiftId];
        } else {
          hWhere = 'status = 1 AND created_at >= ? AND created_at < ?';
          hArgs  = [start, end];
        }
        final rows = await db.rawQuery('''
          SELECT CAST(strftime('%H', created_at) AS INTEGER) as hour,
                 COUNT(*) as orders_count, SUM(grand_total) as revenue
          FROM orders WHERE $hWhere
          GROUP BY hour ORDER BY hour ASC
        ''', hArgs);
        final hourMap = <int, Map<String, Object?>>{};
        for (final r in rows) { hourMap[r['hour'] as int] = r; }
        final result = List.generate(24, (h) => {
          'hour': h,
          'orders_count': (hourMap[h]?['orders_count'] as int?) ?? 0,
          'revenue': (hourMap[h]?['revenue'] as num?)?.toDouble() ?? 0.0,
        });
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/stats', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();
        final orderType = q['order_type'] != null ? int.tryParse(q['order_type']!) : null;
        final locationId = q['location_id'] != null ? int.tryParse(q['location_id']!) : null;
        final waiterId = q['waiter_id'] != null ? int.tryParse(q['waiter_id']!) : null;
        final shiftId = q['shift_id'] != null ? int.tryParse(q['shift_id']!) : null;

        final db = await DatabaseHelper.instance.database;
        final args = <dynamic>[];
        var extra = '';
        if (orderType != null) { extra += ' AND o.order_type = ?'; args.add(orderType); }
        if (locationId != null) { extra += ' AND o.location_id = ?'; args.add(locationId); }
        if (waiterId != null) { extra += ' AND o.waiter_id = ?'; args.add(waiterId); }

        final String baseWhere;
        if (shiftId != null) {
          baseWhere = 'o.status = 1 AND o.shift_id = ?$extra';
          args.insert(0, shiftId);
        } else {
          baseWhere = 'o.status = 1 AND o.created_at >= ? AND o.created_at <= ?$extra';
          args.insertAll(0, [start, end]);
        }

        final ordersRaw = await db.rawQuery('''
          SELECT COUNT(*) as count,
            SUM(grand_total) as total, AVG(grand_total) as avg_check,
            SUM(CASE WHEN order_type=0 THEN grand_total ELSE 0 END) as dine_in_total,
            SUM(CASE WHEN order_type=1 THEN grand_total ELSE 0 END) as takeaway_total
          FROM orders o WHERE $baseWhere
        ''', List.from(args));

        // Payment breakdown from order_payments (handles split payments correctly)
        final payRows = await db.rawQuery('''
          SELECT op.payment_type, SUM(op.amount) as pay_total
          FROM order_payments op JOIN orders o ON op.order_id = o.id
          WHERE $baseWhere
          GROUP BY op.payment_type
        ''', List.from(args));
        final payMap = {
          for (final r in payRows)
            r['payment_type'] as String: (r['pay_total'] as num?)?.toDouble() ?? 0.0
        };
        final metricsRow = Map<String, dynamic>.from(ordersRaw.first);
        metricsRow['cash_total']     = payMap['cash'] ?? 0.0;
        metricsRow['card_total']     = payMap['card'] ?? 0.0;
        metricsRow['terminal_total'] = payMap['terminal'] ?? 0.0;
        metricsRow['bonus_total']    = payMap['bonus'] ?? 0.0;
        metricsRow['debt_total']     = payMap['debt'] ?? 0.0;
        metricsRow['transfer_total'] = payMap['transfer'] ?? 0.0;
        final orders = [metricsRow];

        final topQty = await db.rawQuery('''
          SELECT p.name, SUM(oi.qty) as qty FROM order_items oi
          JOIN products p ON oi.product_id=p.id JOIN orders o ON oi.order_id=o.id
          WHERE $baseWhere GROUP BY p.id ORDER BY qty DESC LIMIT 5
        ''', List.from(args));

        final topRevenue = await db.rawQuery('''
          SELECT p.name, SUM(oi.qty*oi.price) as revenue FROM order_items oi
          JOIN products p ON oi.product_id=p.id JOIN orders o ON oi.order_id=o.id
          WHERE $baseWhere GROUP BY p.id ORDER BY revenue DESC LIMIT 5
        ''', List.from(args));

        return Response.ok(
          jsonEncode({'metrics': orders.first, 'topQty': topQty, 'topRevenue': topRevenue}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/orders', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();
        final orderType = q['order_type'] != null ? int.tryParse(q['order_type']!) : null;
        final locationId = q['location_id'] != null ? int.tryParse(q['location_id']!) : null;
        final waiterId = q['waiter_id'] != null ? int.tryParse(q['waiter_id']!) : null;
        final shiftId = q['shift_id'] != null ? int.tryParse(q['shift_id']!) : null;

        final db = await DatabaseHelper.instance.database;
        final args = <dynamic>[];
        var extra = '';
        if (orderType != null) { extra += ' AND o.order_type = ?'; args.add(orderType); }
        if (locationId != null) { extra += ' AND o.location_id = ?'; args.add(locationId); }
        if (waiterId != null) { extra += ' AND o.waiter_id = ?'; args.add(waiterId); }

        final String ordWhere;
        if (shiftId != null) {
          ordWhere = 'o.status = 1 AND o.shift_id = ?$extra';
          args.insert(0, shiftId);
        } else {
          ordWhere = 'o.status = 1 AND o.created_at >= ? AND o.created_at <= ?$extra';
          args.insertAll(0, [start, end]);
        }

        final rows = await db.rawQuery('''
          SELECT o.*, l.name as location_name, t.name as table_name, w.name as waiter_name
          FROM orders o
          LEFT JOIN locations l ON o.location_id=l.id
          LEFT JOIN tables t ON o.table_id=t.id
          LEFT JOIN waiters w ON o.waiter_id=w.id
          WHERE $ordWhere
          ORDER BY o.created_at DESC
        ''', args);

        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/products', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();
        final orderType = q['order_type'] != null ? int.tryParse(q['order_type']!) : null;
        final locationId = q['location_id'] != null ? int.tryParse(q['location_id']!) : null;
        final waiterId = q['waiter_id'] != null ? int.tryParse(q['waiter_id']!) : null;
        final shiftId = q['shift_id'] != null ? int.tryParse(q['shift_id']!) : null;

        final db = await DatabaseHelper.instance.database;
        final args = <dynamic>[];
        var extra = '';
        if (orderType != null) { extra += ' AND o.order_type = ?'; args.add(orderType); }
        if (locationId != null) { extra += ' AND o.location_id = ?'; args.add(locationId); }
        if (waiterId != null) { extra += ' AND o.waiter_id = ?'; args.add(waiterId); }

        final String pWhere;
        if (shiftId != null) {
          pWhere = 'o.status=1 AND o.shift_id=?$extra';
          args.insert(0, shiftId);
        } else {
          pWhere = 'o.status=1 AND o.created_at>=? AND o.created_at<=?$extra';
          args.insertAll(0, [start, end]);
        }

        final rows = await db.rawQuery('''
          SELECT p.name, p.category, SUM(oi.qty) as total_qty,
            SUM(oi.qty*oi.price) as total_revenue, p.quantity as current_stock
          FROM order_items oi
          JOIN products p ON oi.product_id=p.id JOIN orders o ON oi.order_id=o.id
          WHERE $pWhere
          GROUP BY p.id, p.name, p.quantity ORDER BY total_revenue DESC
        ''', args);

        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/waiters', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();
        final orderType = q['order_type'] != null ? int.tryParse(q['order_type']!) : null;
        final locationId = q['location_id'] != null ? int.tryParse(q['location_id']!) : null;
        final shiftId = q['shift_id'] != null ? int.tryParse(q['shift_id']!) : null;

        final db = await DatabaseHelper.instance.database;
        final args = <dynamic>[];
        var extra = '';
        if (orderType != null) { extra += ' AND o.order_type = ?'; args.add(orderType); }
        if (locationId != null) { extra += ' AND o.location_id = ?'; args.add(locationId); }

        final String wJoinCond;
        if (shiftId != null) {
          wJoinCond = 'o.status=1 AND o.shift_id=?$extra';
          args.insert(0, shiftId);
        } else {
          wJoinCond = 'o.status=1 AND o.created_at>=? AND o.created_at<=?$extra';
          args.insertAll(0, [start, end]);
        }

        final rows = await db.rawQuery('''
          SELECT w.name, w.type as waiter_type, w.value as waiter_value,
            COUNT(o.id) as order_count, SUM(COALESCE(o.grand_total,0)) as total_sales
          FROM waiters w
          LEFT JOIN orders o ON w.id=o.waiter_id AND $wJoinCond
          GROUP BY w.id, w.name, w.type, w.value
          HAVING order_count > 0
        ''', args);

        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/locations', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();

        final db = await DatabaseHelper.instance.database;
        final rows = await db.rawQuery('''
          SELECT l.name, COUNT(o.id) as order_count, SUM(o.grand_total) as total_revenue
          FROM locations l JOIN orders o ON l.id=o.location_id
          WHERE o.status=1 AND o.created_at>=? AND o.created_at<=?
          GROUP BY l.id ORDER BY total_revenue DESC
        ''', [start, end]);

        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/tables', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();

        final db = await DatabaseHelper.instance.database;
        final rows = await db.rawQuery('''
          SELECT t.name as table_name, l.name as location_name,
            COUNT(o.id) as order_count, SUM(o.grand_total) as total_revenue
          FROM tables t JOIN locations l ON t.location_id=l.id
          JOIN orders o ON t.id=o.table_id
          WHERE o.status=1 AND o.created_at>=? AND o.created_at<=?
          GROUP BY t.id ORDER BY total_revenue DESC
        ''', [start, end]);

        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    _router.get('/reports/zreport', (Request request) async {
      try {
        final q = request.url.queryParameters;
        final start = q['start'] ?? DateTime.now().toIso8601String();
        final end = q['end'] ??
            DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 23, 59, 59)
                .toIso8601String();
        final shiftId = q['shift_id'] != null ? int.tryParse(q['shift_id']!) : null;

        final db = await DatabaseHelper.instance.database;

        final String zWhere;
        final List<dynamic> zArgs;
        if (shiftId != null) {
          zWhere = 'o.status=1 AND o.shift_id=?';
          zArgs  = [shiftId];
        } else {
          zWhere = 'o.status=1 AND o.created_at>=? AND o.created_at<=?';
          zArgs  = [start, end];
        }
        final String oWhere = zWhere.replaceAll('o.', '');

        final summaryRaw = await db.rawQuery('''
          SELECT COUNT(*) as count, SUM(grand_total) as total,
            MIN(created_at) as first_order, MAX(created_at) as last_order
          FROM orders WHERE $oWhere
        ''', List.from(zArgs));

        final zPayRows = await db.rawQuery('''
          SELECT op.payment_type, SUM(op.amount) as pay_total
          FROM order_payments op JOIN orders o ON op.order_id = o.id
          WHERE $zWhere
          GROUP BY op.payment_type
        ''', List.from(zArgs));
        final zPayMap = <String, double>{};
        for (final r in zPayRows) {
          final pt = (r['payment_type'] as String? ?? '').toLowerCase();
          final amt = (r['pay_total'] as num?)?.toDouble() ?? 0.0;
          final key = (pt == 'naqd') ? 'cash' : (pt == 'karta') ? 'card' :
                      (pt == 'nasiya') ? 'debt' : pt;
          zPayMap[key] = (zPayMap[key] ?? 0.0) + amt;
        }
        final summaryRow = Map<String, dynamic>.from(summaryRaw.first);
        summaryRow['cash_total']     = zPayMap['cash'] ?? 0.0;
        summaryRow['card_total']     = zPayMap['card'] ?? 0.0;
        summaryRow['terminal_total'] = zPayMap['terminal'] ?? 0.0;
        summaryRow['bonus_total']    = zPayMap['bonus'] ?? 0.0;
        summaryRow['debt_total']     = zPayMap['debt'] ?? 0.0;
        summaryRow['transfer_total'] = zPayMap['transfer'] ?? 0.0;
        // Smena qo'shimcha ma'lumotlari
        if (shiftId != null) {
          final shiftRow = await db.query('shifts', where: 'id=?', whereArgs: [shiftId], limit: 1);
          if (shiftRow.isNotEmpty) {
            summaryRow['shift_opened_at'] = shiftRow.first['opened_at'];
            summaryRow['shift_closed_at'] = shiftRow.first['closed_at'];
            summaryRow['shift_status']    = shiftRow.first['status'];
            summaryRow['opening_cash']    = shiftRow.first['opening_cash'];
            summaryRow['counted_cash']    = shiftRow.first['counted_cash'];
          }
          // Xarajatlar
          final expRow = await db.rawQuery(
            'SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE shift_id=?', [shiftId]);
          summaryRow['total_expenses'] = (expRow.first['total'] as num?)?.toDouble() ?? 0.0;
        }

        final waiterSales = await db.rawQuery('''
          SELECT COALESCE(w.name,'Admin/Saboy') as name, SUM(o.grand_total) as sales
          FROM orders o LEFT JOIN waiters w ON o.waiter_id=w.id
          WHERE $zWhere
          GROUP BY o.waiter_id
        ''', List.from(zArgs));

        final categorySales = await db.rawQuery('''
          SELECT p.category, SUM(oi.qty) as qty, SUM(oi.qty*oi.price) as total
          FROM order_items oi JOIN products p ON oi.product_id=p.id
          JOIN orders o ON oi.order_id=o.id
          WHERE $zWhere
          GROUP BY p.category ORDER BY total DESC
        ''', List.from(zArgs));

        final topProducts = await db.rawQuery('''
          SELECT p.name, SUM(oi.qty) as qty, SUM(oi.qty*oi.price) as revenue
          FROM order_items oi JOIN products p ON oi.product_id=p.id
          JOIN orders o ON oi.order_id=o.id
          WHERE $zWhere
          GROUP BY p.id ORDER BY revenue DESC LIMIT 10
        ''', List.from(zArgs));

        return Response.ok(
          jsonEncode({
            'summary': summaryRow,
            'waiterSales': waiterSales,
            'categorySales': categorySales,
            'topProducts': topProducts,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Remote receipt print — client devices POST here to print main receipt on server
    _router.post('/print_receipt', (Request request) async {
      try {
        final body = await request.readAsString();
        final Map<String, dynamic> payload =
            Map<String, dynamic>.from(jsonDecode(body) as Map);

        final orderId = payload['id'] as String?;
        if (orderId == null || orderId.isEmpty) {
          return Response.badRequest(
              body: jsonEncode({'error': 'order id yuborilmadi'}));
        }

        final db = await DatabaseHelper.instance.database;
        Order order;
        bool orderInDb = false;
        dynamic tableId;

        // 1. Order DB da bor-yo'qligini tekshiramiz
        final orderRows = await db.rawQuery('''
          SELECT o.*,
            t.name as table_name, t.pricing_type, t.hourly_rate,
            t.fixed_amount, t.service_percentage,
            l.name as location_name,
            w.name as waiter_name, w.type as waiter_type, w.value as waiter_value
          FROM orders o
          LEFT JOIN tables t ON o.table_id = t.id
          LEFT JOIN locations l ON o.location_id = l.id
          LEFT JOIN waiters w ON o.waiter_id = w.id
          WHERE o.id = ?
        ''', [orderId]);

        if (orderRows.isNotEmpty) {
          // DB da bor — DB dan to'liq ma'lumot olamiz
          orderInDb = true;
          final orderMap = Map<String, dynamic>.from(orderRows.first);
          tableId = orderMap['table_id'];

          final itemRows = await db.rawQuery('''
            SELECT oi.*, p.name as product_name, p.no_service_charge,
                   p.category as category_id
            FROM order_items oi
            JOIN products p ON oi.product_id = p.id
            WHERE oi.order_id = ?
          ''', [orderId]);

          final items = itemRows.map((r) => OrderItem.fromMap(
            Map<String, dynamic>.from(r),
            productName: r['product_name'] as String? ?? '',
          )).toList();

          // Xona/stol narxini hisoblash
          double roomCharge = (orderMap['room_charge'] as num?)?.toDouble() ?? 0;
          if (roomCharge == 0 && orderMap['pricing_type'] != null) {
            final pricingType = orderMap['pricing_type'] as int? ?? 0;
            final openedAt = orderMap['opened_at'] != null
                ? DateTime.tryParse(orderMap['opened_at'] as String)
                : null;
            if (pricingType == 1 && openedAt != null) {
              final hours = DateTime.now().difference(openedAt).inMinutes / 60.0;
              final hourlyRate = (orderMap['hourly_rate'] as num?)?.toDouble() ?? 0;
              roomCharge = (hours * hourlyRate).roundToDouble();
            } else if (pricingType == 2) {
              roomCharge = (orderMap['fixed_amount'] as num?)?.toDouble() ?? 0;
            } else if (pricingType == 3) {
              final pct = (orderMap['service_percentage'] as num?)?.toDouble() ?? 0;
              final foodTotal = items
                  .where((i) => i.productName != 'noServiceCharge')
                  .fold(0.0, (sum, i) => sum + i.qty * i.price);
              roomCharge = (foodTotal * pct / 100).roundToDouble();
            }
          }

          // Ofisant xizmat haqi hisoblash
          double serviceTotal = (orderMap['service_total'] as num?)?.toDouble() ?? 0;
          if (serviceTotal == 0 &&
              orderMap['waiter_type'] != null &&
              orderMap['waiter_name'] != 'Kassa') {
            final waiterType = orderMap['waiter_type'] as int? ?? 0;
            final waiterValue = (orderMap['waiter_value'] as num?)?.toDouble() ?? 0;
            if (waiterType == 1 && waiterValue > 0) {
              final taxableTotal = items
                  .fold(0.0, (sum, i) => sum + i.qty * i.price);
              serviceTotal = (taxableTotal * waiterValue / 100).roundToDouble();
            } else if (waiterType == 0 && waiterValue > 0) {
              serviceTotal = waiterValue;
            }
          }

          orderMap['room_charge']   = roomCharge;
          orderMap['room_total']    = roomCharge;
          orderMap['service_total'] = serviceTotal;
          orderMap['grand_total']   =
              ((orderMap['total'] as num?)?.toDouble() ?? 0) + roomCharge + serviceTotal;
          orderMap['table_name']    = payload['table_name'] ?? orderMap['table_name'];
          orderMap['location_name'] = payload['location_name'] ?? orderMap['location_name'];
          orderMap['waiter_name']   = payload['waiter_name'] ?? orderMap['waiter_name'];

          order = Order.fromMap(orderMap, items: items);
        } else {
          // DB da yo'q — vaqtinchalik chek (offisant yangi buyurtma qo'shmoqda)
          // Payload da barcha kerakli ma'lumot bor (toPrintPayload() dan keladi)
          order = Order.fromPrintPayload(payload);
          tableId = payload['table_id'];
          debugPrint('[print_receipt] Vaqtinchalik chek — payload dan print: $orderId');
        }

        // bill_requested faqat DB da bor orderlar uchun
        if (orderInDb) {
          await db.update(
            'orders',
            {
              'bill_requested': 1,
              'bill_requested_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [orderId],
          );
          if (tableId != null) {
            WebSocketManager.instance.broadcast('tables_updated', {'table_id': tableId});
          }
        }

        // Serverning o'z printeri orqali chop etamiz
        await PrintingService.printReceipt(order: order);

        return Response.ok(jsonEncode({'ok': true}),
            headers: {'Content-Type': 'application/json'});
      } catch (e, st) {
        debugPrint('[print_receipt] Error: $e\n$st');
        return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}));
      }
    });
  }

  /// Ombor moduli yoqilganmi (`settings.enable_inventory`).
  static Future<bool> _inventoryEnabled() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['enable_inventory'],
        limit: 1,
      );
      return rows.isNotEmpty && rows.first['value'] == 'true';
    } catch (e) {
      debugPrint('[inventory] settings read error: $e');
      return false;
    }
  }

  static String _mobileReportHtml() => r'''
<!DOCTYPE html>
<html lang="uz">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=no,maximum-scale=1.0">
<title>Hisobot Panel</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0F172A;--sf:#1E293B;--sf2:#253047;--bd:#334155;
  --tx:#F8FAFC;--mu:#94A3B8;--mu2:#64748B;
  --ac:#6C5CE7;--acl:rgba(108,92,231,.18);
  --gr:#10B981;--bl:#3B82F6;--rd:#EF4444;
  --yw:#F59E0B;--cy:#06B6D4;--pu:#8B5CF6;
  --nh:60px;
}
html,body{background:var(--bg);color:var(--tx);min-height:100vh;
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;
  -webkit-font-smoothing:antialiased;overflow-x:hidden}
button,input,select{font-family:inherit}
::-webkit-scrollbar{width:3px;height:3px}
::-webkit-scrollbar-thumb{background:var(--bd);border-radius:3px}

/* LOGIN */
#login{display:flex;flex-direction:column;align-items:center;justify-content:center;
  min-height:100vh;padding:32px}
.lgo{font-size:52px;margin-bottom:14px}
.lt{font-size:24px;font-weight:800;margin-bottom:6px}
.ls{color:var(--mu);font-size:13px;margin-bottom:40px}
.pin-i{background:var(--sf);border:2px solid var(--bd);border-radius:14px;
  color:var(--tx);font-size:24px;letter-spacing:8px;padding:16px 20px;
  text-align:center;width:240px;outline:none;transition:border-color .2s;-webkit-appearance:none}
.pin-i:focus{border-color:var(--ac)}
.pin-err{color:var(--rd);font-size:13px;min-height:20px;text-align:center;margin:10px 0}
.pin-btn{background:var(--ac);border:none;border-radius:14px;color:#fff;
  font-size:16px;font-weight:700;padding:16px 0;width:240px;
  cursor:pointer;transition:opacity .15s;-webkit-tap-highlight-color:transparent}
.pin-btn:active{opacity:.8}

/* APP */
#app{display:none;max-width:520px;margin:0 auto;padding-bottom:var(--nh)}

/* HEADER */
.hdr{background:var(--sf);padding:12px 16px;position:sticky;top:0;z-index:200;
  border-bottom:1px solid var(--bd)}
.hdr-r{display:flex;justify-content:space-between;align-items:center}
.hdr-nm{font-size:16px;font-weight:800}
.hdr-sb{font-size:11px;color:var(--mu);margin-top:2px}
.hdr-btns{display:flex;gap:6px}
.hdr-btn{background:var(--bd);border:none;border-radius:10px;color:var(--tx);
  font-size:15px;padding:7px 13px;cursor:pointer;line-height:1}
.hdr-btn:active{opacity:.7}

/* PERIOD BAR */
.period-bar{background:var(--sf);border-bottom:1px solid var(--bd)}
.chips-row{display:flex;gap:5px;overflow-x:auto;padding:10px 12px;scrollbar-width:none}
.chips-row::-webkit-scrollbar{display:none}
.chip{background:transparent;border:1.5px solid var(--bd);border-radius:20px;
  color:var(--mu);font-size:13px;font-weight:600;padding:6px 13px;cursor:pointer;
  transition:all .18s;white-space:nowrap;user-select:none;flex-shrink:0}
.chip.on{background:var(--ac);border-color:var(--ac);color:#fff}
.custom-row{display:none;padding:0 12px 10px;gap:8px;align-items:center}
.custom-row.show{display:flex}
.dt-i{background:var(--sf2);border:1.5px solid var(--bd);border-radius:10px;
  color:var(--tx);font-size:12px;padding:7px 10px;flex:1;outline:none;-webkit-appearance:none}
.dt-i:focus{border-color:var(--ac)}
.dt-ok{background:var(--ac);border:none;border-radius:10px;color:#fff;
  font-size:13px;font-weight:700;padding:7px 14px;cursor:pointer}

/* FILTER */
.flt-tgl{display:flex;justify-content:space-between;align-items:center;
  padding:8px 16px;border-bottom:1px solid var(--bd);background:var(--sf)}
.flt-lbl{font-size:12px;color:var(--mu);font-weight:600}
.flt-btn{background:var(--acl);border:1px solid var(--ac);border-radius:8px;
  color:var(--ac);font-size:12px;font-weight:600;padding:5px 12px;cursor:pointer}
.flt-panel{background:var(--sf);border-bottom:1px solid var(--bd);
  padding:12px 16px;display:none;flex-direction:column;gap:10px}
.flt-panel.show{display:flex}
.flt-grp label{font-size:11px;color:var(--mu);font-weight:700;
  text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px;display:block}
.type-chips{display:flex;gap:5px;flex-wrap:wrap}
.tc{background:var(--sf2);border:1.5px solid var(--bd);border-radius:8px;
  color:var(--mu);font-size:12px;font-weight:600;padding:5px 12px;
  cursor:pointer;user-select:none;transition:all .15s}
.tc.on{background:var(--acl);border-color:var(--ac);color:var(--ac)}
.flt-row{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.flt-sel{background:var(--sf2);border:1.5px solid var(--bd);border-radius:10px;
  color:var(--tx);font-size:13px;padding:8px 12px;width:100%;outline:none}
.flt-sel:focus{border-color:var(--ac)}

/* INFO BAR */
.info-bar{display:flex;justify-content:space-between;font-size:11px;
  color:var(--mu2);padding:6px 12px 4px}

/* TAB PANELS */
.tab-p{display:none;padding:12px}
.tab-p.show{display:block}

/* BOTTOM NAV */
.bot-nav{position:fixed;bottom:0;left:0;right:0;z-index:300;
  background:var(--sf);border-top:1px solid var(--bd);
  display:flex;max-width:520px;margin:0 auto}
.nav-btn{flex:1;display:flex;flex-direction:column;align-items:center;
  justify-content:center;padding:8px 4px;gap:2px;background:none;border:none;
  color:var(--mu);font-size:10px;font-weight:600;cursor:pointer;
  transition:color .15s;-webkit-tap-highlight-color:transparent;user-select:none}
.nav-btn.on{color:var(--ac)}
.nav-ico{font-size:20px;line-height:1}

/* CARDS */
.card{background:var(--sf);border-radius:16px;padding:16px;margin-bottom:10px}
.c-lbl{color:var(--mu);font-size:11px;font-weight:700;letter-spacing:.5px;
  text-transform:uppercase;margin-bottom:8px}
.card.ac-l{border-left:4px solid var(--ac)}

/* KPI */
.kpi-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px}
.kpi{background:var(--sf);border-radius:14px;padding:14px 16px}
.kv{font-size:20px;font-weight:800;margin-bottom:2px}
.kv.lg{font-size:28px;font-weight:900;letter-spacing:-1px}
.ku{color:var(--mu);font-size:11px}

/* PAYMENT ROW */
.pay-row{display:flex;align-items:center;padding:8px 0;border-bottom:1px solid var(--bd)}
.pay-row:last-child{border-bottom:none}
.pay-ico{width:32px;height:32px;border-radius:8px;display:flex;align-items:center;
  justify-content:center;font-size:15px;margin-right:10px;flex-shrink:0}
.pay-info{flex:1;min-width:0}
.pay-nm{font-size:13px;font-weight:600}
.pay-bar-w{height:4px;background:var(--bd);border-radius:2px;margin-top:3px;overflow:hidden}
.pay-bar{height:100%;border-radius:2px;transition:width .5s}
.pay-pct{font-size:10px;color:var(--mu);margin-top:1px}
.pay-amt{font-size:14px;font-weight:800;text-align:right;white-space:nowrap;padding-left:8px}

/* ROW LIST */
.row{display:flex;justify-content:space-between;align-items:center;
  padding:10px 0;border-bottom:1px solid var(--bd)}
.row:last-child{border-bottom:none}
.row-l{display:flex;align-items:center;gap:8px;min-width:0;flex:1}
.row-nm{font-size:14px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.row-sb{font-size:11px;color:var(--mu);margin-top:1px}
.row-v{font-size:14px;font-weight:700;text-align:right;flex-shrink:0;padding-left:8px}

/* RANK BADGE */
.rnk{width:26px;height:26px;border-radius:7px;background:var(--ac);color:#fff;
  font-size:11px;font-weight:800;display:flex;align-items:center;
  justify-content:center;flex-shrink:0}
.rnk.g{background:var(--yw)}.rnk.s{background:#94A3B8}.rnk.b{background:#CD7C4A}

/* BADGE */
.bdg{font-size:11px;font-weight:700;padding:3px 8px;border-radius:6px;white-space:nowrap}
.bdg.cash,.bdg.naqd{background:rgba(16,185,129,.2);color:var(--gr)}
.bdg.card,.bdg.karta{background:rgba(59,130,246,.2);color:var(--bl)}
.bdg.terminal{background:rgba(139,92,246,.2);color:var(--pu)}
.bdg.bonus{background:rgba(245,158,11,.2);color:var(--yw)}
.bdg.debt,.bdg.qarz{background:rgba(239,68,68,.2);color:var(--rd)}
.bdg.transfer{background:rgba(6,182,212,.2);color:var(--cy)}
.bdg.mixed{background:rgba(108,92,231,.2);color:var(--ac)}
.bdg.t0{background:rgba(108,92,231,.15);color:var(--ac)}
.bdg.t1{background:rgba(16,185,129,.15);color:var(--gr)}
.bdg.t2{background:rgba(6,182,212,.15);color:var(--cy)}

/* ORDER CARD */
.ord-c{background:var(--sf);border-radius:14px;padding:14px;margin-bottom:8px}
.ord-top{display:flex;justify-content:space-between;margin-bottom:6px}
.ord-time{font-size:12px;color:var(--mu)}
.ord-amt{font-size:16px;font-weight:800;color:var(--ac)}
.ord-mid{display:flex;justify-content:space-between;align-items:flex-end}
.ord-nm{font-size:13px;font-weight:600}
.ord-wtr{font-size:11px;color:var(--mu);margin-top:2px}
.ord-bdgs{display:flex;gap:4px;flex-wrap:wrap}

/* SUMMARY STRIP */
.sum-strip{background:var(--sf);border-radius:14px;padding:14px 16px;
  margin-bottom:10px;display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.ss{text-align:center}
.ss-v{font-size:16px;font-weight:800}
.ss-l{font-size:10px;color:var(--mu);margin-top:2px}

/* CHART */
.chart-w{position:relative;height:190px;margin-top:4px}

/* WAITER CARD */
.wtr-c{background:var(--sf);border-radius:14px;padding:14px;margin-bottom:8px}
.wtr-top{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px}
.wtr-nm{font-size:15px;font-weight:800}
.wtr-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.wtr-st{background:var(--sf2);border-radius:8px;padding:8px;text-align:center}
.wtr-sv{font-size:13px;font-weight:700}
.wtr-sl{font-size:10px;color:var(--mu);margin-top:1px}

/* Z-REPORT */
.z-hdr{background:linear-gradient(135deg,#3730A3,var(--ac));border-radius:16px;
  padding:20px;text-align:center;margin-bottom:10px}
.z-v{font-size:32px;font-weight:900;letter-spacing:-1px}
.z-l{font-size:12px;color:rgba(255,255,255,.75);margin-top:4px}
.z-grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-top:12px}
.z-mini{background:rgba(255,255,255,.12);border-radius:10px;padding:10px;text-align:center}
.z-mv{font-size:15px;font-weight:800}
.z-ml{font-size:10px;color:rgba(255,255,255,.7);margin-top:2px}

/* CATEGORY CHIPS */
.cat-chips{display:flex;gap:5px;overflow-x:auto;margin-bottom:10px;
  padding-bottom:2px;scrollbar-width:none}
.cat-chips::-webkit-scrollbar{display:none}
.cc{background:var(--sf2);border:1.5px solid var(--bd);border-radius:20px;
  color:var(--mu);font-size:12px;font-weight:600;padding:5px 12px;
  white-space:nowrap;flex-shrink:0;cursor:pointer;user-select:none;transition:all .15s}
.cc.on{background:var(--acl);border-color:var(--ac);color:var(--ac)}

/* SORT BUTTONS */
.sort-row{display:flex;gap:6px;margin-bottom:10px}
.sort-btn{background:var(--sf2);border:1.5px solid var(--bd);border-radius:8px;
  color:var(--mu);font-size:12px;font-weight:600;padding:6px 14px;
  cursor:pointer;transition:all .15s}
.sort-btn.on{background:var(--acl);border-color:var(--ac);color:var(--ac)}

/* LOAD MORE */
.load-more{background:var(--sf2);border:none;border-radius:12px;color:var(--mu);
  font-size:13px;font-weight:600;padding:12px;width:100%;margin-top:4px;cursor:pointer}
.load-more:active{opacity:.7}

/* SMENA SELEKTOR */
.shift-row{display:none;flex-direction:column;gap:6px;padding:0 12px 10px}
.shift-row.show{display:flex}
.shift-item{background:var(--sf2);border:1.5px solid var(--bd);border-radius:12px;
  padding:12px 14px;cursor:pointer;transition:all .15s;
  display:flex;justify-content:space-between;align-items:center}
.shift-item.on{border-color:var(--ac);background:var(--acl)}
.shift-item:active{opacity:.8}
.shift-badge{font-size:11px;font-weight:700;padding:3px 8px;border-radius:6px}
.shift-badge.open{background:rgba(16,185,129,.2);color:var(--gr)}
.shift-badge.closed{background:rgba(148,163,184,.15);color:var(--mu)}

/* SKELETON */
.sk{background:linear-gradient(90deg,var(--bd) 25%,var(--sf2) 50%,var(--bd) 75%);
  background-size:200%;animation:sh 1.5s infinite;border-radius:8px;height:18px;margin:7px 0}
@keyframes sh{0%{background-position:200%}100%{background-position:-200%}}
.empty{color:var(--mu);font-size:13px;padding:24px 0;text-align:center}
</style>
</head>
<body>

<!-- LOGIN -->
<div id="login">
  <div class="lgo">📊</div>
  <div class="lt">Hisobot Panel</div>
  <p class="ls">Kirish uchun PIN kodni kiriting</p>
  <input id="pin" type="password" inputmode="numeric" maxlength="8"
         class="pin-i" placeholder="••••" autocomplete="current-password">
  <p class="pin-err" id="perr"></p>
  <button class="pin-btn" id="lbtn">Kirish</button>
</div>

<!-- APP -->
<div id="app">

  <!-- Header -->
  <div class="hdr">
    <div class="hdr-r">
      <div>
        <div class="hdr-nm" id="rest-nm">Dashboard</div>
        <div class="hdr-sb" id="rest-sb">Yuklanmoqda...</div>
      </div>
      <div class="hdr-btns">
        <button class="hdr-btn" id="refresh-btn">↻</button>
        <button class="hdr-btn" id="logout-btn">⏻</button>
      </div>
    </div>
  </div>

  <!-- Period Bar -->
  <div class="period-bar">
    <div class="chips-row">
      <div class="chip on" data-p="today">Bugun</div>
      <div class="chip" data-p="yesterday">Kecha</div>
      <div class="chip" data-p="week">7 kun</div>
      <div class="chip" data-p="month">Bu oy</div>
      <div class="chip" data-p="prevmonth">O'tgan oy</div>
      <div class="chip" data-p="smena">🔄 Smena</div>
      <div class="chip" data-p="custom">📅 Tanlash</div>
    </div>
    <div class="custom-row" id="custom-row">
      <input type="date" class="dt-i" id="dt-from">
      <span style="color:var(--mu);font-size:12px">→</span>
      <input type="date" class="dt-i" id="dt-to">
      <button class="dt-ok" id="dt-ok">OK</button>
    </div>
    <div class="shift-row" id="shift-row">
      <div id="shift-list-sel"><div class="sk"></div><div class="sk" style="width:75%"></div></div>
    </div>
  </div>

  <!-- Filter Toggle -->
  <div class="flt-tgl">
    <span class="flt-lbl" id="flt-sum">Barcha buyurtmalar</span>
    <button class="flt-btn" id="flt-toggle">⚙ Filtr</button>
  </div>

  <!-- Filter Panel -->
  <div class="flt-panel" id="flt-panel">
    <div class="flt-grp">
      <label>Buyurtma turi</label>
      <div class="type-chips">
        <div class="tc on" data-ot="all">Barchasi</div>
        <div class="tc" data-ot="0">🍽 Zalda</div>
        <div class="tc" data-ot="1">📦 Olib ketish</div>
        <div class="tc" data-ot="2">🛵 Yetkazish</div>
      </div>
    </div>
    <div class="flt-row">
      <div class="flt-grp">
        <label>Joy</label>
        <select class="flt-sel" id="flt-loc"><option value="">Barchasi</option></select>
      </div>
      <div class="flt-grp">
        <label>Xodim</label>
        <select class="flt-sel" id="flt-wtr"><option value="">Barchasi</option></select>
      </div>
    </div>
  </div>

  <!-- Info Bar -->
  <div class="info-bar">
    <span>Yangilangan: <span id="last-upd">—</span></span>
    <span style="color:var(--ac)" id="plbl"></span>
  </div>

  <!-- TAB 0: Analitika -->
  <div class="tab-p show" id="tab-0">
    <div class="card ac-l">
      <div class="c-lbl">Jami tushum</div>
      <div class="kv lg" id="d-total"><div class="sk" style="width:55%"></div></div>
      <div class="ku">so'm</div>
    </div>
    <div class="kpi-grid">
      <div class="kpi">
        <div class="c-lbl">Buyurtmalar</div>
        <div class="kv" id="d-count">—</div>
        <div class="ku">ta</div>
      </div>
      <div class="kpi">
        <div class="c-lbl">O'rtacha chek</div>
        <div class="kv" id="d-avg">—</div>
        <div class="ku">so'm</div>
      </div>
    </div>
    <div class="card" id="d-pay-card">
      <div class="c-lbl">To'lov turlari</div>
      <div id="d-pay"><div class="sk"></div><div class="sk" style="width:75%"></div></div>
    </div>
    <div class="card">
      <div class="c-lbl">Soatlik faollik</div>
      <div class="chart-w"><canvas id="hchart"></canvas></div>
    </div>
    <div class="card">
      <div class="c-lbl">Top mahsulotlar (daromad)</div>
      <div id="d-top"><div class="sk"></div><div class="sk" style="width:80%"></div><div class="sk" style="width:60%"></div></div>
    </div>
  </div>

  <!-- TAB 1: Buyurtmalar -->
  <div class="tab-p" id="tab-1">
    <div class="sum-strip">
      <div class="ss"><div class="ss-v" id="os-c">—</div><div class="ss-l">Buyurtmalar</div></div>
      <div class="ss"><div class="ss-v" id="os-t">—</div><div class="ss-l">Tushum</div></div>
      <div class="ss"><div class="ss-v" id="os-a">—</div><div class="ss-l">O'rtacha</div></div>
    </div>
    <div id="ord-list"><div class="sk"></div><div class="sk" style="width:85%"></div></div>
    <button class="load-more" id="load-more" style="display:none">Ko'proq yuklash ↓</button>
  </div>

  <!-- TAB 2: Mahsulotlar -->
  <div class="tab-p" id="tab-2">
    <div class="cat-chips" id="cat-chips">
      <div class="cc on" data-cat="">Barchasi</div>
    </div>
    <div class="sort-row">
      <button class="sort-btn on" id="s-rev" onclick="setSrt('rev')">💰 Daromad</button>
      <button class="sort-btn" id="s-qty" onclick="setSrt('qty')">📦 Miqdor</button>
    </div>
    <div class="card">
      <div id="prod-list"><div class="sk"></div><div class="sk" style="width:80%"></div><div class="sk" style="width:60%"></div></div>
    </div>
  </div>

  <!-- TAB 3: Xodimlar -->
  <div class="tab-p" id="tab-3">
    <div id="wtr-list"><div class="sk"></div><div class="sk" style="width:75%"></div></div>
  </div>

  <!-- TAB 4: Z-Hisobot -->
  <div class="tab-p" id="tab-4">
    <div id="z-cont"><div class="sk"></div><div class="sk" style="width:80%"></div><div class="sk" style="width:60%"></div></div>
  </div>

  <!-- Bottom Nav -->
  <div class="bot-nav">
    <button class="nav-btn on" data-tab="0"><div class="nav-ico">📊</div><div>Analitika</div></button>
    <button class="nav-btn" data-tab="1"><div class="nav-ico">📋</div><div>Buyurtmalar</div></button>
    <button class="nav-btn" data-tab="2"><div class="nav-ico">🍽</div><div>Mahsulotlar</div></button>
    <button class="nav-btn" data-tab="3"><div class="nav-ico">👤</div><div>Xodimlar</div></button>
    <button class="nav-btn" data-tab="4"><div class="nav-ico">📄</div><div>Z-Hisobot</div></button>
  </div>

</div><!-- #app -->

<script>
// ── STATE ─────────────────────────────────────────────────────────────────────
var T = sessionStorage.getItem('_zt');
var _per = 'today', _cs = null, _ce = null;
var _ot = null, _loc = '', _wtr = '';
var _tab = 0, _ld = [false,false,false,false,false];
var _ords = [], _pg = 0, PG = 25;
var _prods = [], _cat = '', _srt = 'rev';
var _hChart = null, _tmr = null;
// Server tomonidan hisoblangan davr chegaralari (getDayStartTime asosida)
var _srv = {};
// Smena filter
var _shiftId = null, _shiftList = [];

// ── UTILS ─────────────────────────────────────────────────────────────────────
function $e(id){ return document.getElementById(id); }

function fN(n){
  var v = parseFloat(n)||0;
  if(v>=1e9) return (v/1e9).toFixed(1).replace('.0','')+'mlrd';
  if(v>=1e6) return (v/1e6).toFixed(1).replace('.0','')+'mln';
  if(v>=1000) return Math.round(v/1000)+'K';
  return Math.round(v).toString();
}
function fF(n){ return Math.round(parseFloat(n)||0).toLocaleString('uz-UZ'); }
function fDT(iso){
  if(!iso) return '—';
  var d=new Date(iso);
  return ('0'+d.getDate()).slice(-2)+'.'+('0'+(d.getMonth()+1)).slice(-2)+
    ' '+('0'+d.getHours()).slice(-2)+':'+('0'+d.getMinutes()).slice(-2);
}
function fD(iso){
  if(!iso) return '—';
  var d=new Date(iso);
  return ('0'+d.getDate()).slice(-2)+'.'+('0'+(d.getMonth()+1)).slice(-2)+'.'+d.getFullYear();
}

function getR(){
  // Display uchun Date object qaytaradi
  // _srv mavjud bo'lsa — server raw string dan Date yasaymiz (faqat display uchun)
  if(_per!=='custom' && _srv[_per]) return [new Date(_srv[_per][0]),new Date(_srv[_per][1])];
  var n=new Date(),y=n.getFullYear(),m=n.getMonth(),d=n.getDate();
  function mk(dy,dm,dd){ return new Date(y+dy,m+dm,d+dd); }
  if(_per==='today')     return [mk(0,0,0),mk(0,0,1)];
  if(_per==='yesterday') return [mk(0,0,-1),mk(0,0,0)];
  if(_per==='week')      return [mk(0,0,-6),mk(0,0,1)];
  if(_per==='month')     return [new Date(y,m,1),mk(0,0,1)];
  if(_per==='prevmonth') return [new Date(y,m-1,1),new Date(y,m,1)];
  if(_per==='custom'&&_cs){ var e=_ce?new Date(_ce.getTime()+86400000):mk(0,0,1); return [_cs,e]; }
  return [mk(0,0,0),mk(0,0,1)];
}

function bQ(){
  if(_shiftId!==null) return 'shift_id='+_shiftId;
  var q;
  // Server raw string (mahalliy vaqt, Z siz) mavjud bo'lsa — shuni yuboramiz
  // toISOString() ishlatmaslik kerak — u UTC ga o'tkazib DB taqqoslashni buzadi
  if(_per!=='custom' && _srv[_per]){
    q='start='+encodeURIComponent(_srv[_per][0])+'&end='+encodeURIComponent(_srv[_per][1]);
  } else {
    var r=getR();
    // Custom yoki fallback uchun ham mahalliy vaqt string yasaymiz (toISOString() EMAS)
    function toLocal(dt){
      var pad=function(n){return ('0'+n).slice(-2);};
      return dt.getFullYear()+'-'+pad(dt.getMonth()+1)+'-'+pad(dt.getDate())
        +'T'+pad(dt.getHours())+':'+pad(dt.getMinutes())+':'+pad(dt.getSeconds())+'.000';
    }
    q='start='+encodeURIComponent(toLocal(r[0]))+'&end='+encodeURIComponent(toLocal(r[1]));
  }
  if(_ot!==null) q+='&order_type='+_ot;
  if(_loc) q+='&location_id='+_loc;
  if(_wtr) q+='&waiter_id='+_wtr;
  return q;
}

function rnk(i){ return 'rnk'+(i===0?' g':i===1?' s':i===2?' b':''); }

var PAYS=[
  {k:'cash_total',     l:'Naqd',      i:'💵', c:'#10B981'},
  {k:'card_total',     l:'Karta',     i:'💳', c:'#3B82F6'},
  {k:'terminal_total', l:'Terminal',  i:'🖥',  c:'#8B5CF6'},
  {k:'bonus_total',    l:'Bonus',     i:'⭐', c:'#F59E0B'},
  {k:'transfer_total', l:"O'tkazma",  i:'📲', c:'#06B6D4'},
  {k:'debt_total',     l:'Qarz',      i:'📒', c:'#EF4444'},
];

function payBdg(pt){
  var map={cash:'cash',naqd:'cash',card:'card',karta:'card',
    terminal:'terminal',bonus:'bonus',transfer:'transfer',debt:'debt',qarz:'debt'};
  var lbl={cash:'Naqd',naqd:'Naqd',card:'Karta',karta:'Karta',
    terminal:'Terminal',bonus:'Bonus',transfer:"O'tkazma",debt:'Qarz',qarz:'Qarz'};
  var k=(pt||'').toLowerCase();
  return '<span class="bdg '+(map[k]||'mixed')+'">'+(lbl[k]||pt||'Aralash')+'</span>';
}

function otBdg(t){
  if(t===0) return '<span class="bdg t0">Zalda</span>';
  if(t===1) return '<span class="bdg t1">Olib ketish</span>';
  if(t===2) return '<span class="bdg t2">Yetkazish</span>';
  return '';
}

// ── API ───────────────────────────────────────────────────────────────────────
async function apig(path){
  var r=await fetch(path,{headers:{'Authorization':'Bearer '+T}});
  if(r.status===401){ doLogout(); throw new Error('unauth'); }
  if(!r.ok) throw new Error('HTTP '+r.status);
  return r.json();
}

// ── DASHBOARD ─────────────────────────────────────────────────────────────────
async function loadDash(){
  var q=bQ();
  var stats,hourly;
  try{
    var res=await Promise.all([apig('/reports/stats?'+q),apig('/reports/hourly?'+q)]);
    stats=res[0]; hourly=res[1];
  }catch(e){ stats={metrics:{},topRevenue:[],topQty:[]}; hourly=[]; }

  var m=(stats&&stats.metrics)||{};
  $e('d-total').textContent=fF(m.total||0);
  $e('d-count').textContent=(m.count||0)+' ta';
  $e('d-avg').textContent=fN(m.avg_check||0);

  // Payment breakdown
  var tot=parseFloat(m.total)||1;
  var pays=PAYS.filter(function(p){ return parseFloat(m[p.k])>0; });
  $e('d-pay').innerHTML=pays.length?pays.map(function(p){
    var amt=parseFloat(m[p.k])||0, pct=Math.round(amt/tot*100);
    return '<div class="pay-row">'+
      '<div class="pay-ico" style="background:'+p.c+'22">'+p.i+'</div>'+
      '<div class="pay-info">'+
        '<div class="pay-nm">'+p.l+'</div>'+
        '<div class="pay-bar-w"><div class="pay-bar" style="width:'+pct+'%;background:'+p.c+'"></div></div>'+
        '<div class="pay-pct">'+pct+'%</div>'+
      '</div>'+
      '<div class="pay-amt" style="color:'+p.c+'">'+fF(amt)+'</div>'+
    '</div>';
  }).join(''):'<div class="empty">To\'lov yo\'q</div>';

  // Hourly chart
  var revs=[];
  for(var h=0;h<24;h++){
    var f=null;
    for(var j=0;j<hourly.length;j++){ if(hourly[j].hour===h){f=hourly[j];break;} }
    revs.push(f?parseFloat(f.revenue)||0:0);
  }
  var lbls=['0','1','2','3','4','5','6','7','8','9','10','11',
            '12','13','14','15','16','17','18','19','20','21','22','23'];
  function buildChart(){
    if(_hChart){ _hChart.data.datasets[0].data=revs; _hChart.update('none'); return; }
    if(typeof Chart==='undefined'){ window._chartPending=buildChart; return; }
    _hChart=new Chart(document.getElementById('hchart').getContext('2d'),{
      type:'bar',
      data:{labels:lbls,datasets:[{data:revs,
        backgroundColor:'rgba(108,92,231,.55)',borderColor:'#6C5CE7',
        borderWidth:1,borderRadius:3}]},
      options:{responsive:true,maintainAspectRatio:false,
        plugins:{legend:{display:false},
          tooltip:{callbacks:{label:function(c){return fF(c.raw)+" so'm";}}}},
        scales:{
          x:{ticks:{color:'#94A3B8',font:{size:9},maxRotation:0},grid:{color:'rgba(51,65,85,.5)'}},
          y:{ticks:{color:'#94A3B8',font:{size:9},callback:function(v){return fN(v);}},
             grid:{color:'rgba(51,65,85,.5)'}}
        }
      }
    });
  }
  buildChart();

  // Top products
  var tp=(stats.topRevenue||[]).slice(0,5);
  $e('d-top').innerHTML=tp.length?tp.map(function(p,i){
    return '<div class="row">'+
      '<div class="row-l"><div class="'+rnk(i)+'">'+(i+1)+'</div>'+
      '<div class="row-nm">'+p.name+'</div></div>'+
      '<div class="row-v" style="color:var(--ac)">'+fN(p.revenue)+'</div></div>';
  }).join(''):'<div class="empty">Ma\'lumot yo\'q</div>';
}

// ── ORDERS ────────────────────────────────────────────────────────────────────
async function loadOrds(){
  var q=bQ();
  try{ _ords=await apig('/reports/orders?'+q); }catch(e){ return; }
  _pg=0;
  var tot=_ords.reduce(function(s,o){return s+(parseFloat(o.grand_total)||parseFloat(o.total)||0);},0);
  $e('os-c').textContent=_ords.length;
  $e('os-t').textContent=fN(tot);
  $e('os-a').textContent=fN(_ords.length?tot/_ords.length:0);
  renderOrds();
}

function renderOrds(){
  var slice=_ords.slice(0,(_pg+1)*PG);
  $e('ord-list').innerHTML=slice.length?slice.map(function(o){
    var amt=parseFloat(o.grand_total)||parseFloat(o.total)||0;
    var place=o.table_name||(o.location_name)||'—';
    return '<div class="ord-c">'+
      '<div class="ord-top">'+
        '<span class="ord-time">'+fDT(o.created_at)+'</span>'+
        '<span class="ord-amt">'+fF(amt)+' so\'m</span>'+
      '</div>'+
      '<div class="ord-mid">'+
        '<div><div class="ord-nm">'+place+'</div>'+
        '<div class="ord-wtr">'+(o.waiter_name||'Kassa')+'</div></div>'+
        '<div class="ord-bdgs">'+otBdg(o.order_type)+payBdg(o.payment_type)+'</div>'+
      '</div>'+
    '</div>';
  }).join(''):'<div class="empty">Buyurtma topilmadi</div>';
  $e('load-more').style.display=((_pg+1)*PG<_ords.length)?'':'none';
}

// ── PRODUCTS ──────────────────────────────────────────────────────────────────
async function loadProds(){
  var q=bQ();
  try{ _prods=await apig('/reports/products?'+q); }catch(e){ return; }

  var cats={};
  _prods.forEach(function(p){ if(p.category) cats[p.category]=true; });
  var catList=Object.keys(cats).sort();
  var ch='<div class="cc on" data-cat="">Barchasi</div>';
  catList.forEach(function(c){ ch+='<div class="cc" data-cat="'+c+'">'+c+'</div>'; });
  $e('cat-chips').innerHTML=ch;
  document.querySelectorAll('.cc').forEach(function(el){
    el.addEventListener('click',function(){
      document.querySelectorAll('.cc').forEach(function(x){x.classList.remove('on');});
      el.classList.add('on'); _cat=el.getAttribute('data-cat'); renderProds();
    });
  });
  renderProds();
}

function setSrt(s){
  _srt=s;
  $e('s-rev').className='sort-btn'+(s==='rev'?' on':'');
  $e('s-qty').className='sort-btn'+(s==='qty'?' on':'');
  renderProds();
}

function renderProds(){
  var list=_prods.filter(function(p){return !_cat||p.category===_cat;});
  list=list.slice().sort(function(a,b){
    return _srt==='rev'?(b.total_revenue-a.total_revenue):(b.total_qty-a.total_qty);
  });
  $e('prod-list').innerHTML=list.length?list.map(function(p,i){
    return '<div class="row">'+
      '<div class="row-l"><div class="'+rnk(i)+'">'+(i+1)+'</div>'+
      '<div style="min-width:0"><div class="row-nm">'+p.name+'</div>'+
      '<div class="row-sb">'+(p.category||'')+'</div></div></div>'+
      '<div style="text-align:right;flex-shrink:0;padding-left:8px">'+
        '<div class="row-v" style="color:var(--ac)">'+fF(p.total_revenue)+'</div>'+
        '<div class="row-sb">'+Math.round(p.total_qty||0)+' ta</div>'+
      '</div></div>';
  }).join(''):'<div class="empty">Mahsulot topilmadi</div>';
}

// ── WAITERS ───────────────────────────────────────────────────────────────────
async function loadWtrs(){
  var q=bQ();
  var ws;
  try{ ws=await apig('/reports/waiters?'+q); }catch(e){ return; }
  if(!ws||!ws.length){ $e('wtr-list').innerHTML='<div class="empty">Ma\'lumot yo\'q</div>'; return; }
  $e('wtr-list').innerHTML=ws.map(function(w,i){
    var s=parseFloat(w.total_sales)||0, c=parseInt(w.order_count)||0;
    return '<div class="wtr-c">'+
      '<div class="wtr-top">'+
        '<div style="display:flex;align-items:center;gap:8px">'+
          '<div class="'+rnk(i)+'" style="width:32px;height:32px;font-size:14px">'+(i+1)+'</div>'+
          '<div><div class="wtr-nm">'+(w.name||'Nomalum')+'</div>'+
          '<div style="font-size:11px;color:var(--mu)">'+c+' ta buyurtma</div></div>'+
        '</div>'+
        '<div style="text-align:right">'+
          '<div style="font-size:16px;font-weight:800;color:var(--ac)">'+fN(s)+'</div>'+
          '<div style="font-size:11px;color:var(--mu)">so\'m</div>'+
        '</div>'+
      '</div>'+
      '<div class="wtr-grid">'+
        '<div class="wtr-st"><div class="wtr-sv">'+fN(s)+'</div><div class="wtr-sl">Tushum</div></div>'+
        '<div class="wtr-st"><div class="wtr-sv">'+c+'</div><div class="wtr-sl">Buyurtma</div></div>'+
        '<div class="wtr-st"><div class="wtr-sv">'+fN(c?s/c:0)+'</div><div class="wtr-sl">O\'rtacha</div></div>'+
      '</div>'+
    '</div>';
  }).join('');
}

// ── Z-REPORT ──────────────────────────────────────────────────────────────────
async function loadZ(){
  var q=bQ();
  var z;
  try{ z=await apig('/reports/zreport?'+q); }catch(e){ return; }
  var s=z.summary||{}, tot=parseFloat(s.total)||0, cnt=parseInt(s.count)||0;
  var r=getR();
  var d1=fD(r[0].toISOString()), d2=fD(new Date(r[1]-1).toISOString());

  var payH=PAYS.map(function(p){
    var a=parseFloat(s[p.k])||0;
    if(!a) return '';
    return '<div class="pay-row">'+
      '<div class="pay-ico" style="background:'+p.c+'22">'+p.i+'</div>'+
      '<div class="pay-info"><div class="pay-nm">'+p.l+'</div></div>'+
      '<div class="pay-amt" style="color:'+p.c+'">'+fF(a)+' so\'m</div></div>';
  }).filter(Boolean).join('');

  var wH=(z.waiterSales||[]).map(function(w,i){
    return '<div class="row">'+
      '<div class="row-l"><div class="'+rnk(i)+'">'+(i+1)+'</div>'+
      '<div class="row-nm">'+(w.name||'—')+'</div></div>'+
      '<div class="row-v" style="color:var(--ac)">'+fF(w.sales||0)+' so\'m</div></div>';
  }).join('');

  var cH=(z.categorySales||[]).map(function(c,i){
    return '<div class="row">'+
      '<div class="row-l"><div class="'+rnk(i)+'">'+(i+1)+'</div>'+
      '<div><div class="row-nm">'+(c.category||'Boshqa')+'</div>'+
      '<div class="row-sb">'+Math.round(c.qty||0)+' ta</div></div></div>'+
      '<div class="row-v" style="color:var(--ac)">'+fF(c.total||0)+' so\'m</div></div>';
  }).join('');

  var pH=(z.topProducts||[]).slice(0,10).map(function(p,i){
    return '<div class="row">'+
      '<div class="row-l"><div class="'+rnk(i)+'">'+(i+1)+'</div>'+
      '<div><div class="row-nm">'+p.name+'</div>'+
      '<div class="row-sb">'+Math.round(p.qty||0)+' ta</div></div></div>'+
      '<div style="text-align:right;flex-shrink:0;padding-left:8px">'+
        '<div class="row-v" style="color:var(--ac)">'+fF(p.revenue||0)+'</div>'+
      '</div></div>';
  }).join('');

  var hdrDate=_shiftId!==null?(
    (function(){
      var sv=_shiftList.find(function(x){return x.id===_shiftId;});
      return sv?'Smena: '+fD(sv.opened_at)+(sv.closed_at?' → '+fD(sv.closed_at):''):d1+' — '+d2;
    })()
  ):(d1+' — '+d2);
  var expHtml='';
  if(s.total_expenses&&parseFloat(s.total_expenses)>0){
    expHtml='<div class="card"><div class="c-lbl">Xarajatlar</div>'
      +'<div class="row"><div class="row-l"><div class="row-nm">Jami xarajat</div></div>'
      +'<div class="row-v" style="color:var(--rd)">'+fF(s.total_expenses)+' so\'m</div></div></div>';
  }
  $e('z-cont').innerHTML=
    '<div class="z-hdr">'+
      '<div style="font-size:12px;color:rgba(255,255,255,.7);margin-bottom:6px">'+hdrDate+'</div>'+
      '<div class="z-v">'+fF(tot)+' so\'m</div>'+
      '<div class="z-l">Jami tushum</div>'+
      '<div class="z-grid">'+
        '<div class="z-mini"><div class="z-mv">'+cnt+'</div><div class="z-ml">Buyurtmalar</div></div>'+
        '<div class="z-mini"><div class="z-mv">'+fN(cnt?tot/cnt:0)+'</div><div class="z-ml">O\'rtacha chek</div></div>'+
        (s.opening_cash!==undefined?'<div class="z-mini"><div class="z-mv">'+fN(s.opening_cash||0)+'</div><div class="z-ml">Ochilish</div></div>':'')+
      '</div>'+
    '</div>'+
    (payH?'<div class="card"><div class="c-lbl">To\'lov turlari</div>'+payH+'</div>':'')+
    expHtml+
    (wH?'<div class="card"><div class="c-lbl">Xodimlar savdosi</div>'+wH+'</div>':'')+
    (cH?'<div class="card"><div class="c-lbl">Kategoriyalar</div>'+cH+'</div>':'')+
    (pH?'<div class="card"><div class="c-lbl">Top mahsulotlar</div>'+pH+'</div>':'');
}

// ── SMENA ─────────────────────────────────────────────────────────────────────
async function loadShiftList(){
  $e('shift-list-sel').innerHTML='<div class="sk"></div><div class="sk" style="width:75%"></div>';
  try{
    var r=await fetch('/reports/shifts?limit=20',{headers:{'Authorization':'Bearer '+T}});
    if(r.ok) _shiftList=await r.json();
  }catch(e){ _shiftList=[]; }
  renderShiftList();
}

function renderShiftList(){
  var el=$e('shift-list-sel');
  if(!_shiftList||!_shiftList.length){
    el.innerHTML='<div class="empty">Smena topilmadi</div>'; return;
  }
  el.innerHTML=_shiftList.map(function(s,i){
    var isOpen=s.status===0;
    var opened=fDT(s.opened_at);
    var closed=s.closed_at?fDT(s.closed_at):'Ochiq';
    var isSel=_shiftId===s.id;
    var tot=parseFloat(s.total_sales)||0;
    var cnt=parseInt(s.order_count)||0;
    return '<div class="shift-item'+(isSel?' on':'')+'" onclick="selectShift('+s.id+')">'
      +'<div>'
        +'<div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">'
          +'<span style="font-weight:800;font-size:13px">Smena #'+(i+1)+'</span>'
          +'<span class="shift-badge '+(isOpen?'open':'closed')+'">'+(isOpen?'Ochiq':'Yopildi')+'</span>'
        +'</div>'
        +'<div style="font-size:11px;color:var(--mu)">'+opened+(isOpen?'':' → '+closed)+'</div>'
        +'<div style="font-size:11px;color:var(--mu)">Ochgan: '+(s.opened_by_name||'—')+'</div>'
      +'</div>'
      +'<div style="text-align:right;flex-shrink:0;padding-left:10px">'
        +'<div style="font-weight:800;color:var(--ac);font-size:15px">'+fF(tot)+'</div>'
        +'<div style="font-size:10px;color:var(--mu)">so\'m</div>'
        +'<div style="font-size:11px;color:var(--mu);margin-top:2px">'+cnt+' buyurtma</div>'
      +'</div>'
    +'</div>';
  }).join('');
}

function selectShift(id){
  _shiftId=(_shiftId===id)?null:id;
  renderShiftList();
  var s=_shiftId!==null?_shiftList.find(function(x){return x.id===id;}):null;
  $e('plbl').textContent=s?('Smena: '+fD(s.opened_at)):'Smena';
  _ld=[false,false,false,false,false];
  loadTab(_tab);
  $e('last-upd').textContent=new Date().toLocaleTimeString('uz-UZ',{hour:'2-digit',minute:'2-digit'});
}

// ── LOADER ────────────────────────────────────────────────────────────────────
async function loadTab(n){
  try{
    if(n===0) await loadDash();
    else if(n===1) await loadOrds();
    else if(n===2) await loadProds();
    else if(n===3) await loadWtrs();
    else if(n===4) await loadZ();
    _ld[n]=true;
  }catch(e){ if(e.message!=='unauth') console.error(e); }
  $e('last-upd').textContent=new Date().toLocaleTimeString('uz-UZ',{hour:'2-digit',minute:'2-digit'});
}

function reload(){
  _ld=[false,false,false,false,false];
  loadTab(_tab);
}

// ── TAB SWITCH ────────────────────────────────────────────────────────────────
function switchTab(n){
  _tab=n;
  document.querySelectorAll('.tab-p').forEach(function(p,i){
    p.className='tab-p'+(i===n?' show':'');
  });
  document.querySelectorAll('.nav-btn').forEach(function(b){
    b.className='nav-btn'+(parseInt(b.getAttribute('data-tab'))===n?' on':'');
  });
  if(!_ld[n]) loadTab(n);
}

// ── PERIOD CHIPS ──────────────────────────────────────────────────────────────
var PLBL={today:'Bugun',yesterday:'Kecha',week:'7 kun',month:'Bu oy',prevmonth:"O'tgan oy",custom:'Tanlangan',smena:'Smena'};
function updPLbl(){
  if(_per==='smena'&&_shiftId!==null){
    var s=_shiftList.find(function(x){return x.id===_shiftId;});
    $e('plbl').textContent=s?'Smena: '+fD(s.opened_at):'Smena';
  } else {
    $e('plbl').textContent=PLBL[_per]||'';
  }
}

document.querySelectorAll('.chip').forEach(function(el){
  el.addEventListener('click',function(){
    _per=el.getAttribute('data-p');
    document.querySelectorAll('.chip').forEach(function(c){c.classList.remove('on');});
    el.classList.add('on');
    var isCustom=_per==='custom';
    var isSmena=_per==='smena';
    $e('custom-row').className='custom-row'+(isCustom?' show':'');
    $e('shift-row').className='shift-row'+(isSmena?' show':'');
    if(isSmena){
      _shiftId=null;
      loadShiftList();
    } else {
      _shiftId=null;
      if(!isCustom) reload();
    }
    updPLbl();
  });
});

$e('dt-ok').addEventListener('click',function(){
  var f=$e('dt-from').value, t=$e('dt-to').value;
  if(f&&t){ _cs=new Date(f); _ce=new Date(t); reload(); updPLbl(); }
});

// ── FILTER PANEL ──────────────────────────────────────────────────────────────
$e('flt-toggle').addEventListener('click',function(){
  var p=$e('flt-panel');
  p.className='flt-panel'+(p.classList.contains('show')?'':' show');
});

document.querySelectorAll('.tc').forEach(function(el){
  el.addEventListener('click',function(){
    document.querySelectorAll('.tc').forEach(function(c){c.classList.remove('on');});
    el.classList.add('on');
    var v=el.getAttribute('data-ot');
    _ot=(v==='all')?null:parseInt(v);
    reload(); updFltSum();
  });
});

$e('flt-loc').addEventListener('change',function(){ _loc=this.value; reload(); updFltSum(); });
$e('flt-wtr').addEventListener('change',function(){ _wtr=this.value; reload(); updFltSum(); });

function updFltSum(){
  var parts=[];
  if(_ot!==null) parts.push(['Zalda','Olib ketish','Yetkazish'][_ot]);
  var ls=$e('flt-loc'), ws=$e('flt-wtr');
  if(_loc) parts.push(ls.options[ls.selectedIndex].text);
  if(_wtr) parts.push(ws.options[ws.selectedIndex].text);
  $e('flt-sum').textContent=parts.length?parts.join(' · '):'Barcha buyurtmalar';
}

// ── LOAD MORE ─────────────────────────────────────────────────────────────────
$e('load-more').addEventListener('click',function(){ _pg++; renderOrds(); });

// ── NAV ───────────────────────────────────────────────────────────────────────
document.querySelectorAll('.nav-btn').forEach(function(el){
  el.addEventListener('click',function(){ switchTab(parseInt(el.getAttribute('data-tab'))); });
});

$e('refresh-btn').addEventListener('click', reload);

// ── AUTH ──────────────────────────────────────────────────────────────────────
async function doLogin(){
  var pin=$e('pin').value.trim();
  $e('perr').textContent='';
  if(!pin) return;
  $e('lbtn').disabled=true;
  try{
    var r=await fetch('/auth/login',{method:'POST',
      headers:{'Content-Type':'application/json'},body:JSON.stringify({pin:pin})});
    var d=await r.json();
    if(!r.ok){ $e('perr').textContent=(d&&d.message)||"PIN noto'g'ri"; return; }
    T=d.token; sessionStorage.setItem('_zt',T); await showApp();
  }catch(e){ $e('perr').textContent="Serverga ulanib bo'lmadi"; }
  finally{ $e('lbtn').disabled=false; }
}

function doLogout(){
  sessionStorage.removeItem('_zt'); T=null;
  $e('login').style.display=''; $e('app').style.display='none';
  $e('pin').value=''; clearInterval(_tmr);
}

async function showApp(){
  $e('login').style.display='none'; $e('app').style.display='block';
  try{
    var res=await Promise.all([
      fetch('/settings',{headers:{'Authorization':'Bearer '+T}}).then(function(r){return r.json();}),
      apig('/locations'),
      apig('/waiters'),
    ]);
    $e('rest-nm').textContent=res[0].restaurant_name||res[0].name||'Hisobot';
    $e('rest-sb').textContent='Hisobot paneli';
    var ls=$e('flt-loc'), ws=$e('flt-wtr');
    (res[1]||[]).forEach(function(l){
      var o=document.createElement('option'); o.value=l.id; o.textContent=l.name; ls.appendChild(o);
    });
    (res[2]||[]).forEach(function(w){
      var o=document.createElement('option'); o.value=w.id; o.textContent=w.name; ws.appendChild(o);
    });
  }catch(e){ $e('rest-sb').textContent='Hisobot paneli'; }
  // Server tomonida hisoblangan davr chegaralarini yuklaymiz
  // Bu Flutter ilovasidagi getDayStartTime() bilan bir xil natija beradi
  try{
    var pr=await fetch('/reports/periods',{headers:{'Authorization':'Bearer '+T}});
    if(pr.ok){
      var pd=await pr.json();
      ['today','yesterday','week','month','prevmonth'].forEach(function(k){
        if(pd[k]&&pd[k].length===2){
          // Raw string (mahalliy vaqt, Z siz) saqlayamiz — toISOString() UTC ga o'tkazib yuboradi
          _srv[k]=pd[k]; // ['2026-06-23T06:00:00.000', '2026-06-24T06:00:00.000']
        }
      });
    }
  }catch(_){}
  try{ updPLbl(); }catch(_){}
  try{ switchTab(0); }catch(_){}
  clearInterval(_tmr);
  _tmr=setInterval(reload,5*60*1000);
}

$e('lbtn').addEventListener('click',doLogin);
$e('pin').addEventListener('keydown',function(e){ if(e.key==='Enter') doLogin(); });
$e('logout-btn').addEventListener('click',function(){
  if(confirm("Chiqishni istaysizmi?")) doLogout();
});

if(T){
  fetch('/auth/me',{headers:{'Authorization':'Bearer '+T}})
    .then(function(r){ if(r.ok) showApp(); else doLogout(); })
    .catch(function(){ doLogout(); });
}
</script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js" onload="if(window._chartPending)window._chartPending()"></script>
</body>
</html>
''';
}

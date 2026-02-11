import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../database_helper.dart';
import '../utils/price_formatter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/customer.dart';

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
    // 1. Auth
    _router.post('/auth/login', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final pin = payload['pin'] as String?;

      if (pin == null || pin.isEmpty)
        return Response.badRequest(
          body: jsonEncode({'error': 'PIN kodi kiritilmadi'}),
        );

      final db = await DatabaseHelper.instance.database;

      // Waiters login
      final waiters = await db.query(
        'waiters',
        where: 'pin_code = ? AND is_active = 1',
        whereArgs: [pin],
      );

      if (waiters.isNotEmpty) {
        final waiter = waiters.first;
        return Response.ok(
          jsonEncode({
            'token': 'waiter-token-${waiter['id']}',
            'user': {
              'id': waiter['id'],
              'name': waiter['name'],
              'role': 'waiter',
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
        return Response.ok(
          jsonEncode({
            'token': 'admin-token-${user['id']}',
            'user': {
              'id': user['id'],
              'name': user['name'],
              'role': user['role'], // admin or cashier
            },
          }),
        );
      }

      return Response.forbidden(
        jsonEncode({'error': 'PIN kod noto‘g‘ri yoki xodim faol emas'}),
      );
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
          t.*, 
          l.name as location_name,
          o.id as order_id, 
          o.total as order_total, 
          o.waiter_id, 
          w.name as waiter_name,
          o.opened_at
        FROM tables t
        LEFT JOIN locations l ON t.location_id = l.id
        LEFT JOIN orders o ON t.id = o.table_id AND o.status = 0
        LEFT JOIN waiters w ON o.waiter_id = w.id
      ''');
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

    // 4. Waiters
    _router.get('/waiters', (Request request) async {
      final data = await DatabaseHelper.instance.queryAll('waiters');
      return Response.ok(jsonEncode(data));
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
      return Response.ok(jsonEncode({'status': 'success'}));
    });

    // 8. Orders
    _router.post('/orders/open', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final tableId = payload['table_id'] as int;

      // Enforce waiter_id from token
      final authHeader = request.headers['Authorization'] ?? '';
      int waiterId = 1; // Default
      if (authHeader.startsWith('Bearer waiter-token-')) {
        waiterId =
            int.tryParse(authHeader.replaceFirst('Bearer waiter-token-', '')) ??
            1;
      }

      final orderType = payload['order_type'] as int? ?? 0;

      final db = await DatabaseHelper.instance.database;

      // Check if table already has open order
      final existing = await db.query(
        'orders',
        where: 'table_id = ? AND status = 0',
        whereArgs: [tableId],
      );
      if (existing.isNotEmpty) {
        return Response.badRequest(body: 'Table already has an open order');
      }

      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      await db.transaction((txn) async {
        await txn.insert('orders', {
          'id': orderId,
          'total': 0.0,
          'payment_type': 'Pending',
          'created_at': DateTime.now().toIso8601String(),
          'order_type': orderType,
          'table_id': tableId,
          'waiter_id': waiterId,
          'status': 0, // open
          'opened_at': DateTime.now().toIso8601String(),
        });

        await txn.update(
          'tables',
          {'status': 1},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      });

      return Response.ok(jsonEncode({'order_id': orderId}));
    });

    _router.get('/orders/<id>', (Request request, String id) async {
      final db = await DatabaseHelper.instance.database;
      final orders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (orders.isEmpty) return Response.notFound('Order not found');

      final items = await db.rawQuery(
        '''
        SELECT oi.*, p.name as product_name
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id = ?
      ''',
        [id],
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

      await db.transaction((txn) async {
        // Delete existing items for simplicity in MVP (or use update logic)
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [id]);

        double total = 0;
        for (var item in items) {
          final double price = (item['price'] as num).toDouble();
          final int qty = (item['qty'] as num).toInt();
          total += price * qty;

          await txn.insert('order_items', {
            'order_id': id,
            'product_id': item['product_id'],
            'qty': qty,
            'price': price,
          });
        }

        await txn.update(
          'orders',
          {'total': total},
          where: 'id = ?',
          whereArgs: [id],
        );
      });

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

      // Check if order has items
      final items = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [id],
      );

      if (items.isNotEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'error': "Buyurtmada taomlar mavjud, bekor qilib bo'lmaydi",
          }),
        );
      }

      // Delete order and free table
      await db.transaction((txn) async {
        await txn.delete('orders', where: 'id = ?', whereArgs: [id]);

        if (tableId != null) {
          await txn.update(
            'tables',
            {'status': 0},
            where: 'id = ?',
            whereArgs: [tableId],
          );
        }
      });

      return Response.ok(jsonEncode({'status': 'success'}));
    });
    // 5. Reports View (for Telegram WebApp)
    _router.get('/reports/view', (Request request) async {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String().split('T')[0];

      final summary = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as count, 
          SUM(total) as total,
          SUM(CASE WHEN payment_type = 'Cash' OR payment_type = 'Naqd' THEN total ELSE 0 END) as cash_total,
          SUM(CASE WHEN payment_type = 'Card' OR payment_type = 'Karta' THEN total ELSE 0 END) as card_total,
          SUM(CASE WHEN payment_type = 'Terminal' THEN total ELSE 0 END) as terminal_total
        FROM orders
        WHERE status = 1 AND date(created_at) = date(?)
      ''',
        [now],
      );

      final topProducts = await db.rawQuery(
        '''
        SELECT p.name, SUM(oi.qty * oi.price) as revenue
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        JOIN orders o ON oi.order_id = o.id
        WHERE o.status = 1 AND date(o.created_at) = date(?)
        GROUP BY p.id
        ORDER BY revenue DESC
        LIMIT 5
      ''',
        [now],
      );

      final metrics = summary.first;
      final total = (metrics['total'] as num?)?.toDouble() ?? 0.0;
      final count = (metrics['count'] as num?)?.toInt() ?? 0;
      final cash = (metrics['cash_total'] as num?)?.toDouble() ?? 0.0;
      final card = (metrics['card_total'] as num?)?.toDouble() ?? 0.0;
      final terminal = (metrics['terminal_total'] as num?)?.toDouble() ?? 0.0;

      final html =
          '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zelly POS Hisoboti</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 20px; background: #f1f5f9; color: #1e293b; }
        .card { background: white; border-radius: 16px; padding: 24px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1); margin-bottom: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { margin: 0; font-size: 24px; color: #4c1d95; }
        .metric-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; }
        .metric-card { background: #f8fafc; padding: 12px; border-radius: 12px; text-align: center; }
        .metric-value { font-size: 18px; font-weight: bold; margin-top: 5px; }
        .metric-label { font-size: 12px; color: #64748b; text-transform: uppercase; }
        .total-card { background: #4c1d95; color: white; text-align: center; padding: 25px; margin-bottom: 20px; border-radius: 16px; }
        .total-value { font-size: 32px; font-weight: bold; margin: 10px 0; }
        .product-list { margin-top: 20px; }
        .product-item { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #f1f5f9; }
        .product-item:last-child { border-bottom: none; }
        .product-name { font-weight: 500; }
        .product-price { color: #059669; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>ZELLY POS</h1>
        <p style="color: #64748b; margin: 5px 0;">Bugungi hisobot (${now})</p>
    </div>

    <div class="total-card">
        <div class="metric-label" style="color: rgba(255,255,255,0.7)">Umumiy tushum</div>
        <div class="total-value">${PriceFormatter.format(total)} so'm</div>
        <div style="font-size: 14px;">${count} ta buyurtma</div>
    </div>

    <div class="metric-grid">
        <div class="metric-card">
            <div class="metric-label">Naqd</div>
            <div class="metric-value" style="color: #059669;">${PriceFormatter.format(cash)}</div>
        </div>
        <div class="metric-card">
            <div class="metric-label">Karta</div>
            <div class="metric-value" style="color: #2563eb;">${PriceFormatter.format(card)}</div>
        </div>
        <div class="metric-card">
            <div class="metric-label">Terminal</div>
            <div class="metric-value" style="color: #6366f1;">${PriceFormatter.format(terminal)}</div>
        </div>
    </div>

    <div class="card" style="margin-top: 20px;">
        <div class="metric-label" style="margin-bottom: 15px; font-weight: bold;">Top Sotuvlar</div>
        <div class="product-list">
            ${topProducts.map((p) => '''
            <div class="product-item">
                <span class="product-name">${p['name']}</span>
                <span class="product-price">${PriceFormatter.format((p['revenue'] as num).toDouble())} so'm</span>
            </div>
            ''').join('')}
        </div>
    </div>
</body>
</html>
      ''';

      return Response.ok(html, headers: {'Content-Type': 'text/html'});
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
  }
}

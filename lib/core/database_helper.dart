import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tezzro_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationSupportDirectory();
    final path = join(dbPath.path, filePath);

    final db = await openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );

    // Ensure default waiter "Kassa" exists
    await _ensureDefaultWaiterExists(db);
    // Ensure default admin user exists
    await _ensureDefaultAdminExists(db);
    // Ensure default cashier user exists
    await _ensureDefaultCashierExists(db);

    return db;
  }

  Future<void> _ensureDefaultWaiterExists(Database db) async {
    final res = await db.query(
      'waiters',
      where: 'name = ?',
      whereArgs: ['Kassa'],
    );
    if (res.isEmpty) {
      await db.insert('waiters', {
        'name': 'Kassa',
        'type': 0, // fixed
        'value': 0.0,
      });
    }
  }

  Future<void> _ensureDefaultAdminExists(Database db) async {
    final res = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: ['Admin'],
    );
    if (res.isEmpty) {
      await db.insert('users', {
        'name': 'Admin',
        'pin': '1234',
        'role': 'admin',
        'is_active': 1,
      });
    }
  }

  Future<void> _ensureDefaultCashierExists(Database db) async {
    final res = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: ['Kassir'],
    );
    if (res.isEmpty) {
      await db.insert('users', {
        'name': 'Kassir',
        'pin': '5555',
        'role': 'cashier',
        'is_active': 1,
      });
    }
  }

  Future<int?> getDefaultWaiterId() async {
    final db = await database;
    final res = await db.query(
      'waiters',
      where: 'name = ?',
      whereArgs: ['Kassa'],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['id'] as int;
    }
    return null;
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)',
      );
    }
    if (oldVersion < 4) {
      // Step 1: Add new tables for Restaurant Mode
      await db.execute('''
        CREATE TABLE IF NOT EXISTS locations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          location_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          status INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS waiters (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type INTEGER NOT NULL,
          value REAL NOT NULL
        )
      ''');

      // Step 2: Upgrade orders table
      // SQLite doesn't support adding multiple columns in one ALTER TABLE easily or adding constraints.
      // But we can add them one by one.
      await db.execute(
        'ALTER TABLE orders ADD COLUMN order_type INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE orders ADD COLUMN table_id INTEGER');
      await db.execute('ALTER TABLE orders ADD COLUMN location_id INTEGER');
      await db.execute('ALTER TABLE orders ADD COLUMN waiter_id INTEGER');
      await db.execute(
        'ALTER TABLE orders ADD COLUMN status INTEGER NOT NULL DEFAULT 1',
      );
    }

    if (oldVersion < 5) {
      // Add indexes for reporting
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders (created_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders (order_type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_location ON orders (location_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_waiter ON orders (waiter_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_table ON orders (table_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items (order_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items (product_id)',
      );
    }

    if (oldVersion < 6) {
      // Add room pricing columns to tables
      await db.execute(
        'ALTER TABLE tables ADD COLUMN pricing_type INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tables ADD COLUMN hourly_rate REAL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tables ADD COLUMN fixed_amount REAL DEFAULT 0',
      );

      // Add timing and charge columns to orders
      await db.execute('ALTER TABLE orders ADD COLUMN opened_at TEXT');
      await db.execute('ALTER TABLE orders ADD COLUMN closed_at TEXT');
      await db.execute(
        'ALTER TABLE orders ADD COLUMN room_charge REAL DEFAULT 0',
      );
    }

    if (oldVersion < 7) {
      await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
    }

    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE orders ADD COLUMN paid_amount REAL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE orders ADD COLUMN receipt_change REAL DEFAULT 0',
      );
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS waiter_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          waiter_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          paid_at TEXT NOT NULL,
          note TEXT,
          created_by TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_waiter_payments_lookup ON waiter_payments (waiter_id, paid_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_waiter_history ON orders (waiter_id, created_at)',
      );
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NOT NULL,
          role TEXT NOT NULL,
          is_active INTEGER DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 11) {
      // Check if columns exist before adding them to avoid duplicate column errors
      try {
        await db.execute('ALTER TABLE waiters ADD COLUMN pin_code TEXT');
      } catch (e) {
        // Column already exists, skip
        print('pin_code column already exists: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE waiters ADD COLUMN is_active INTEGER DEFAULT 1',
        );
      } catch (e) {
        // Column already exists, skip
        print('is_active column already exists: $e');
      }

      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_waiter_pin ON waiters (pin_code) WHERE pin_code IS NOT NULL',
        );
      } catch (e) {
        // Index already exists, skip
        print('idx_waiter_pin index already exists: $e');
      }
    }

    if (oldVersion < 12) {
      try {
        await db.execute(
          'ALTER TABLE orders ADD COLUMN food_total REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE orders ADD COLUMN room_total REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE orders ADD COLUMN service_total REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE orders ADD COLUMN grand_total REAL DEFAULT 0',
        );
      } catch (e) {
        print('Error adding new total columns: $e');
      }
    }

    if (oldVersion < 13) {
      // Add tables for Expenses and Customers
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES expense_categories (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          debt REAL DEFAULT 0,
          credit REAL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER,
          type TEXT NOT NULL, -- 'outlay', 'payment', 'expense_outlay'
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id $idType,
  name $textType
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS products (
  id $idType,
  name $textType,
  price $realType,
  category $textType,
  is_active $integerType DEFAULT 1,
  image_path TEXT
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  total $realType,
  payment_type $textType,
  created_at $textType,
  order_type INTEGER NOT NULL DEFAULT 0,
  table_id INTEGER,
  location_id INTEGER,
  waiter_id INTEGER,
  status INTEGER NOT NULL DEFAULT 1,
  opened_at TEXT,
  closed_at TEXT,
  room_charge REAL DEFAULT 0,
  paid_amount REAL DEFAULT 0,
  receipt_change REAL DEFAULT 0,
  food_total REAL NOT NULL DEFAULT 0,
  room_total REAL NOT NULL DEFAULT 0,
  service_total REAL NOT NULL DEFAULT 0,
  grand_total REAL NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS order_items (
  id $idType,
  order_id $textType,
  product_id $integerType,
  qty $integerType,
  price $realType,
  FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS locations (
  id $idType,
  name $textType
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS tables (
  id $idType,
  location_id INTEGER NOT NULL,
  name $textType,
  status INTEGER NOT NULL DEFAULT 0,
  pricing_type INTEGER NOT NULL DEFAULT 0,
  hourly_rate REAL DEFAULT 0,
  fixed_amount REAL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS waiters (
  id $idType,
  name $textType,
  type $integerType,
  value $realType,
  pin_code TEXT UNIQUE,
  is_active $integerType DEFAULT 1
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS waiter_payments (
  id $idType,
  waiter_id $integerType,
  amount $integerType,
  paid_at $textType,
  note TEXT,
  created_by TEXT
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS users (
  id $idType,
  name $textType,
  pin $textType,
  role $textType,
  is_active $integerType DEFAULT 1
)
''');

    // Add indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders (created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_type ON orders (order_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_location ON orders (location_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_waiter ON orders (waiter_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_table ON orders (table_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items (order_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items (product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_waiter_payments_lookup ON waiter_payments (waiter_id, paid_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_waiter_history ON orders (waiter_id, created_at)',
    );

    // New tables for v13
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id $idType,
        name $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id $idType,
        category_id $integerType,
        amount $realType,
        note TEXT,
        created_at $textType,
        FOREIGN KEY (category_id) REFERENCES expense_categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id $idType,
        name $textType,
        phone TEXT,
        debt REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        created_at $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id $idType,
        customer_id INTEGER,
        type $textType,
        amount $realType,
        note TEXT,
        created_at $textType,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');
  }

  // Generic methods
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> queryByColumn(
    String table,
    String column,
    dynamic value,
  ) async {
    final db = await instance.database;
    return await db.query(table, where: '$column = ?', whereArgs: [value]);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await instance.database;
    return await db.query(table);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await instance.database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await instance.database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

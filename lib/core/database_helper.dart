import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? databasePathOverride; // Testlar uchun yo'lni o'zgartirish

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(databasePathOverride ?? 'tezzro_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (filePath == inMemoryDatabasePath) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getApplicationSupportDirectory();
      path = join(dbPath.path, filePath);
    }

    final db = await openDatabase(
      path,
      version: 26,
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
      await db.execute(
        'ALTER TABLE tables ADD COLUMN pricing_type INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tables ADD COLUMN hourly_rate REAL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tables ADD COLUMN fixed_amount REAL DEFAULT 0',
      );

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
      try {
        await db.execute('ALTER TABLE waiters ADD COLUMN pin_code TEXT');
      } catch (e) {
        print('pin_code column already exists: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE waiters ADD COLUMN is_active INTEGER DEFAULT 1',
        );
      } catch (e) {
        print('is_active column already exists: $e');
      }

      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_waiter_pin ON waiters (pin_code) WHERE pin_code IS NOT NULL',
        );
      } catch (e) {
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
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');
    }

    if (oldVersion < 14) {
      try {
        await db.execute(
          'ALTER TABLE tables ADD COLUMN service_percentage REAL DEFAULT 0',
        );
      } catch (e) {
        print('Error adding service_percentage column: $e');
      }
    }

    if (oldVersion < 15) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN is_set INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_bundles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bundle_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity REAL NOT NULL DEFAULT 1,
            UNIQUE(bundle_id, product_id)
          )
        ''');
      } catch (e) {
        print('Error upgrading to v15: $e');
      }
    }

    if (oldVersion < 16) {
      try {
        await db.execute(
          'ALTER TABLE order_items ADD COLUMN bundle_items_json TEXT',
        );
      } catch (e) {
        print('Error upgrading to v16: $e');
      }
    }

    if (oldVersion < 17) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN color TEXT');
      } catch (e) {
        print('Error upgrading to v17: $e');
      }
    }

    if (oldVersion < 18) {
      try {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN sort_order INTEGER DEFAULT 0',
        );
      } catch (e) {
        print('Error upgrading to v18: $e');
      }
    }

    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cache_key TEXT UNIQUE,
          response TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 20) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN sort_order INTEGER DEFAULT 0',
        );
      } catch (e) {
        print('Error upgrading products table to v20: $e');
      }
    }

    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN quantity REAL');
      } catch (e) {
        print('Error upgrading products table to v21: $e');
      }
    }

    if (oldVersion < 22) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS printers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            display_name TEXT,
            type TEXT,
            ip_address TEXT,
            port INTEGER,
            printer_name TEXT,
            category_ids TEXT
          )
        ''');
      } catch (e) {
        print('Error upgrading database to v22: $e');
      }
    }
    if (oldVersion < 23) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN track_type INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE products ADD COLUMN allow_negative_stock INTEGER NOT NULL DEFAULT 0',
        );

        await db.execute('''
          CREATE TABLE IF NOT EXISTS ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            base_unit TEXT NOT NULL CHECK (base_unit IN ('g', 'ml', 'pcs')),
            min_stock REAL DEFAULT 0,
            is_active INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS ingredient_stock (
            ingredient_id INTEGER PRIMARY KEY,
            on_hand REAL NOT NULL DEFAULT 0,
            updated_at TEXT,
            FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ingredient_id INTEGER,
            type TEXT NOT NULL CHECK (type IN ('IN', 'OUT', 'ADJUST', 'RETURN')),
            qty REAL NOT NULL,
            reason TEXT,
            ref_table TEXT,
            ref_id TEXT,
            note TEXT,
            created_at TEXT NOT NULL,
            created_by INTEGER,
            FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS recipes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER UNIQUE,
            yield_qty REAL DEFAULT 1,
            is_active INTEGER DEFAULT 1,
            FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS recipe_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recipe_id INTEGER,
            ingredient_id INTEGER,
            qty REAL NOT NULL,
            FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE,
            FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE,
            UNIQUE(recipe_id, ingredient_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS order_inventory_flags (
            order_id TEXT PRIMARY KEY,
            deducted INTEGER DEFAULT 0,
            deducted_at TEXT,
            reversed INTEGER DEFAULT 0,
            reversed_at TEXT
          )
        ''');

        // Indexes for performance
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_movements_lookup ON stock_movements (ingredient_id, created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON recipe_items (recipe_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_track_type ON products (track_type)',
        );
      } catch (e) {
        print('Error upgrading database to v23: $e');
      }
    }

    if (oldVersion < 24) {
      try {
        // Buyurtmalarni smenaga bog'lash uchun shift_id ustunini qo'shish
        await db.execute('ALTER TABLE orders ADD COLUMN shift_id INTEGER');

        // Smenalar jadvali
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shifts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            opened_at TEXT NOT NULL,
            closed_at TEXT,
            opened_by INTEGER NOT NULL,
            closed_by INTEGER,
            opening_cash REAL DEFAULT 0,
            counted_cash REAL,
            difference REAL,
            notes TEXT,
            status INTEGER DEFAULT 0, -- 0: Ochiq, 1: Yopilgan
            FOREIGN KEY (opened_by) REFERENCES users (id),
            FOREIGN KEY (closed_by) REFERENCES users (id)
          )
        ''');

        // Naqd pul harakatlari jadvali (inkassatsiya, xarajatlar va h.k.)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cash_movements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            shift_id INTEGER NOT NULL,
            type TEXT NOT NULL, -- 'IN' yoki 'OUT'
            amount REAL NOT NULL,
            reason TEXT,
            note TEXT,
            created_at TEXT NOT NULL,
            created_by INTEGER NOT NULL,
            FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE,
            FOREIGN KEY (created_by) REFERENCES users (id)
          )
        ''');
      } catch (e) {
        print('Error upgrading database to v24: $e');
      }
    }

    if (oldVersion < 25) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            action TEXT NOT NULL,
            entity TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            before_json TEXT,
            after_json TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs (user_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs (entity, entity_id)',
        );
      } catch (e) {
        print('Error upgrading database to v25: $e');
      }
    }

    if (oldVersion < 26) {
      try {
        // Analitika uchun indekslar (tezkor qidirish uchun)
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_status_date ON orders (status, created_at)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_orders_waiter ON orders (waiter_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items (product_id)',
        );
      } catch (e) {
        print('Error upgrading database to v26: $e');
      }
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
  name $textType,
  color TEXT,
  sort_order INTEGER DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS products (
  id $idType,
  name $textType,
  price $realType,
  category $textType,
  is_active $integerType DEFAULT 1,
  image_path TEXT,
  is_set $integerType DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  quantity REAL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS product_bundles (
  id $idType,
  bundle_id $integerType,
  product_id $integerType,
  quantity $realType DEFAULT 1,
  UNIQUE(bundle_id, product_id)
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
  bundle_items_json TEXT,
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
  fixed_amount REAL DEFAULT 0,
  service_percentage REAL DEFAULT 0
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_cache (
        id $idType,
        cache_key TEXT UNIQUE,
        response TEXT,
        created_at $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS printers (
        id $idType,
        display_name TEXT,
        type TEXT,
        ip_address TEXT,
        port INTEGER,
        printer_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredients (
        id $idType,
        name $textType,
        base_unit TEXT NOT NULL CHECK (base_unit IN ('g', 'ml', 'pcs')),
        min_stock REAL DEFAULT 0,
        is_active $integerType DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredient_stock (
        ingredient_id INTEGER PRIMARY KEY,
        on_hand REAL NOT NULL DEFAULT 0,
        updated_at TEXT,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id $idType,
        ingredient_id INTEGER,
        type TEXT NOT NULL CHECK (type IN ('IN', 'OUT', 'ADJUST', 'RETURN')),
        qty REAL NOT NULL,
        reason TEXT,
        ref_table TEXT,
        ref_id TEXT,
        note TEXT,
        created_at $textType,
        created_by INTEGER,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id $idType,
        product_id INTEGER UNIQUE,
        yield_qty REAL DEFAULT 1,
        is_active $integerType DEFAULT 1,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_items (
        id $idType,
        recipe_id INTEGER,
        ingredient_id INTEGER,
        qty REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id) ON DELETE CASCADE,
        UNIQUE(recipe_id, ingredient_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_inventory_flags (
        order_id TEXT PRIMARY KEY,
        deducted INTEGER DEFAULT 0,
        deducted_at TEXT,
        reversed INTEGER DEFAULT 0,
        reversed_at TEXT
      )
    ''');

    // Add new indexes for v23
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_lookup ON stock_movements (ingredient_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recipe_items_recipe ON recipe_items (recipe_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_track_type ON products (track_type)',
    );

    // Smena (Shift) v24
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id $idType,
        opened_at $textType,
        closed_at $textType,
        opened_by INTEGER NOT NULL,
        closed_by INTEGER,
        opening_cash REAL DEFAULT 0,
        counted_cash REAL,
        difference REAL,
        notes TEXT,
        status INTEGER DEFAULT 0,
        FOREIGN KEY (opened_by) REFERENCES users (id),
        FOREIGN KEY (closed_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id $idType,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL, -- 'IN' yoki 'OUT'
        amount REAL NOT NULL,
        reason TEXT,
        note TEXT,
        created_at $textType,
        created_by INTEGER NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Audit Log v25
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id $idType,
        user_id INTEGER,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        before_json TEXT,
        after_json TEXT,
        created_at $textType,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs (user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs (entity, entity_id)',
    );

    // Analytics Indexes v26
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_status_date ON orders (status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_waiter ON orders (waiter_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items (product_id)',
    );
  }

  // Generic methods
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> queryByColumn(
    String table,
    String column,
    dynamic value,
  ) async {
    final db = await database;
    return await db.query(table, where: '$column = ?', whereArgs: [value]);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getApplicationSupportDirectory();
    return join(dbPath.path, 'tezzro_pos.db');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

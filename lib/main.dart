import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/database_helper.dart';
import 'core/license_service.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'features/mgmt/products_mgmt_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/mgmt/categories_mgmt_screen.dart';
import 'providers/category_provider.dart';
import 'providers/location_provider.dart';
import 'providers/table_provider.dart';
import 'providers/waiter_provider.dart';
import 'providers/report_provider.dart';
import 'providers/printer_provider.dart';
import 'features/mgmt/printer_settings_screen.dart';
import 'features/mgmt/locations_mgmt_screen.dart';
import 'features/mgmt/tables_mgmt_screen.dart';
import 'features/mgmt/waiters_mgmt_screen.dart';
import 'features/pos/tables_screen.dart';
import 'providers/receipt_settings_provider.dart';
import 'features/settings/receipt_settings_screen.dart';
import 'providers/app_settings_provider.dart';
import 'features/settings/pin_settings_screen.dart';
import 'features/settings/brand_settings_screen.dart';
import 'features/settings/connection_settings_screen.dart';
import 'providers/connectivity_provider.dart';
import 'features/activation/activation_screen.dart';
import 'providers/developer_provider.dart';
import 'features/mgmt/developer_mgmt_screen.dart';
import 'features/settings/telegram_settings_screen.dart';
import 'providers/user_provider.dart';
import 'features/mgmt/cashiers_mgmt_screen.dart';
import 'providers/expense_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/ai_provider.dart';
import 'features/mgmt/expenses_screen.dart';
import 'features/mgmt/customers_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Window management setup
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ZELLY',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setFullScreen(true);
  });

  // Initialize Database
  await DatabaseHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProductProvider()..loadProducts(),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider()..loadCategories(),
        ),
        ChangeNotifierProvider(
          create: (_) => PrinterProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationProvider()..loadLocations(),
        ),
        ChangeNotifierProvider(create: (_) => TableProvider()..loadTables()),
        ChangeNotifierProvider(create: (_) => WaiterProvider()..loadWaiters()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(
          create: (_) => ReceiptSettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => DeveloperProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()..loadUsers()),
        ChangeNotifierProvider(
          create: (_) => ExpenseProvider()
            ..loadCategories()
            ..loadExpenses(),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomerProvider()..loadCustomers(),
        ),
        ChangeNotifierProvider(create: (_) => AiProvider()),
      ],
      child: const TezzroApp(),
    ),
  );
}

class TezzroApp extends StatelessWidget {
  const TezzroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1280, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'ZELLY',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: FutureBuilder<bool>(
            future: LicenseService.instance.isActivated(),
            builder: (context, snapshot) {
              // Show loading while checking license
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Check if activated
              if (snapshot.data == true) {
                return const LoginScreen(); // Activated - go to login
              }

              return const ActivationScreen(); // Not activated - show activation
            },
          ),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _enteredPin = '';

  void _handlePinPress(String value) {
    if (value == '⌫') {
      if (_enteredPin.isNotEmpty) {
        setState(
          () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1),
        );
      }
    } else if (value == 'C') {
      setState(() => _enteredPin = '');
    } else {
      if (_enteredPin.length < 4) {
        setState(() => _enteredPin += value);
        if (_enteredPin.length == 4) {
          _verifyPin();
        }
      }
    }
  }

  void _verifyPin() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.mode == ConnectivityMode.client) {
      final success = await connectivity.login(_enteredPin);
      if (success) {
        if (mounted) {
          // Force remote reload for all data
          context.read<ProductProvider>().loadProducts(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<CategoryProvider>().loadCategories(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<TableProvider>().loadTables(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<LocationProvider>().loadLocations(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<WaiterProvider>().loadWaiters(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<UserProvider>().loadUsers(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<ExpenseProvider>().loadCategories(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<ExpenseProvider>().loadExpenses(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<CustomerProvider>().loadCustomers(
            connectivity: connectivity,
            forceRemote: true,
          );
          context.read<LocationProvider>().loadLocations(
            connectivity: connectivity,
            forceRemote: true,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN xato yoki serverga ulanib bo‘lmadi!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _enteredPin = '');
        }
      }
    } else {
      // Local or Server mode
      final db = DatabaseHelper.instance;
      final userResults = await db.queryByColumn('users', 'pin', _enteredPin);

      if (userResults.isNotEmpty) {
        final user = userResults.first;
        if (user['is_active'] == 1) {
          connectivity.setCurrentUser(user);
          if (mounted) {
            // Force reload for non-admin local users if server IP exists
            final forceRemote = user['role'] != 'admin';
            context.read<ProductProvider>().loadProducts(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<CategoryProvider>().loadCategories(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<TableProvider>().loadTables(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<LocationProvider>().loadLocations(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<WaiterProvider>().loadWaiters(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<UserProvider>().loadUsers(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<ExpenseProvider>().loadCategories(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<ExpenseProvider>().loadExpenses(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<CustomerProvider>().loadCustomers(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );
            context.read<LocationProvider>().loadLocations(
              connectivity: connectivity,
              forceRemote: forceRemote,
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainLayout()),
            );
          }
          return;
        }
      }

      // Fallback for settings login pin (backward compatibility)
      final settings = context.read<AppSettingsProvider>();
      if (_enteredPin == settings.loginPin) {
        connectivity.setCurrentUser({'name': 'Admin', 'role': 'admin'});
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainLayout()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Noto\'g\'ri PIN kod!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _enteredPin = '');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left: Numpad
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Consumer<ConnectivityProvider>(
                    builder: (context, connectivity, _) {
                      final isClient =
                          connectivity.mode == ConnectivityMode.client;
                      return Column(
                        children: [
                          Text(
                            isClient ? 'Ofitsiant PIN kodi' : 'Kirish',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (connectivity.lastError != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                connectivity.lastError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ConnectionSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_ethernet, size: 18),
                    label: const Text('Ulanish sozlamalari'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tizimga kirish uchun PIN kodni kiriting',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                  ),
                  const SizedBox(height: 60),
                  // PIN Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _enteredPin.length > index
                              ? const Color(0xFF4C1D95)
                              : const Color(0xFFF1F5F9),
                          border: Border.all(
                            color: _enteredPin.length > index
                                ? const Color(0xFF4C1D95)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Numpad
                  SizedBox(
                    width: 320,
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        ...[
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                        ].map((n) => _buildPinButton(n)),
                        _buildPinButton(
                          'C',
                          color: Colors.orange.shade50,
                          textColor: Colors.orange.shade700,
                        ),
                        _buildPinButton('0'),
                        _buildPinButton(
                          '⌫',
                          color: Colors.red.shade50,
                          textColor: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right: Brand Image
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: const Color(0xFFF8FAFC),
                image: settings.brandImagePath != null
                    ? DecorationImage(
                        image: FileImage(File(settings.brandImagePath!)),
                        fit: BoxFit.cover,
                      )
                    : const DecorationImage(
                        image: AssetImage('assets/images/login_default.png'),
                        fit: BoxFit.cover,
                      ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.restaurantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Text(
                      'Smart POS & Business Automation',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinButton(String text, {Color? color, Color? textColor}) {
    return Material(
      color: color ?? const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _handlePinPress(text),
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isExpanded = true;

  final List<Widget> _screens = [
    const TablesScreen(),
    const ProductsMgmtScreen(),
    const CategoriesMgmtScreen(),
    const LocationsMgmtScreen(),
    const TablesMgmtScreen(),
    const WaitersMgmtScreen(),
    const ReportsScreen(),
    const PrinterSettingsScreen(),
    const ReceiptSettingsScreen(),
    const PinSettingsScreen(),
    const BrandSettingsScreen(),
    const ConnectionSettingsScreen(),
    const TelegramSettingsScreen(),
    const CashiersMgmtScreen(),
    const ExpensesScreen(),
    const CustomersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final user = connectivity.currentUser;
    final role = user?['role'] ?? 'admin';

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 250 : 70,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                _buildSidebarHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    children: [
                      // Stollar - All roles can see
                      _buildSidebarItem(0, Icons.grid_view_outlined, 'Stollar'),

                      // Admin - sees everything
                      if (role == 'admin') ...[
                        _buildSidebarItem(
                          1,
                          Icons.inventory_2_outlined,
                          'Mahsulotlar',
                        ),
                        _buildSidebarItem(
                          2,
                          Icons.category_outlined,
                          'Kategoriyalar',
                        ),
                        _buildSidebarItem(3, Icons.layers_outlined, 'Joylar'),
                        _buildSidebarItem(
                          4,
                          Icons.table_bar_outlined,
                          'Stollar (Sozlamalar)',
                        ),
                        _buildSidebarItem(
                          5,
                          Icons.people_outline,
                          'Ofitsiantlar',
                        ),
                        _buildSidebarItem(
                          13,
                          Icons.person_add_alt_1_outlined,
                          'Kassirlar',
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader('Moliya'),
                        _buildSidebarItem(
                          14,
                          Icons.payments_outlined,
                          'Xarajatlar',
                        ),
                        _buildSidebarItem(
                          15,
                          Icons.groups_outlined,
                          'Mijozlar',
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader('Tahlil'),
                        _buildSidebarItem(
                          6,
                          Icons.bar_chart_rounded,
                          'Hisobotlar',
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader('Sozlamalar'),
                        _buildSidebarItem(7, Icons.print_outlined, 'Printer'),
                        _buildSidebarItem(
                          8,
                          Icons.receipt_long_outlined,
                          'Chek',
                        ),
                        _buildSidebarItem(9, Icons.lock_outline, 'PIN kod'),
                        _buildSidebarItem(
                          10,
                          Icons.branding_watermark_outlined,
                          'Brend',
                        ),
                        _buildSidebarItem(
                          11,
                          Icons.settings_ethernet_outlined,
                          'Ulanish',
                        ),
                        _buildSidebarItem(12, Icons.send_outlined, 'Telegram'),
                      ],

                      // Cashier - limited access
                      if (role == 'cashier') ...[
                        _buildSidebarItem(
                          1,
                          Icons.inventory_2_outlined,
                          'Mahsulotlar',
                        ),
                        _buildSidebarItem(
                          2,
                          Icons.category_outlined,
                          'Kategoriyalar',
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader('Sozlamalar'),
                        _buildSidebarItem(7, Icons.print_outlined, 'Printer'),
                        _buildSidebarItem(
                          8,
                          Icons.receipt_long_outlined,
                          'Chek',
                        ),
                      ],

                      // Waiter - only tables (already shown above)
                    ],
                  ),
                ),
                _buildSidebarBottom(user, role),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 20 : 0),
      child: Row(
        mainAxisAlignment: _isExpanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          if (_isExpanded) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeveloperMgmtScreen(),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ZELLY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'POS tizimi',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    if (!_isExpanded) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final bool active = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.05),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: _isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (_isExpanded)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: active ? 24 : 0,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                SizedBox(width: _isExpanded ? 16 : 0),
                Icon(
                  icon,
                  color: active ? AppTheme.secondaryColor : Colors.white60,
                  size: 22,
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white60,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarBottom(Map<String, dynamic>? user, String role) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.black12),
      child: Column(
        children: [
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.person, size: 20, color: Colors.white60),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['name'] ?? 'Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          role == 'admin' ? 'Admin' : 'Kassir',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      size: 18,
                      color: Colors.white30,
                    ),
                    onPressed: () {
                      context.read<ConnectivityProvider>().setCurrentUser(null);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: _isExpanded
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isExpanded
                      ? Icons.keyboard_double_arrow_left
                      : Icons.keyboard_double_arrow_right,
                  color: Colors.white30,
                  size: 20,
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
              if (_isExpanded)
                const Text(
                  'v1.0.2',
                  style: TextStyle(color: Colors.white12, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

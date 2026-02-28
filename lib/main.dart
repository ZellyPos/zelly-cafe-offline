import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/database_helper.dart';
import 'core/services/license_service.dart';
import 'core/update_service.dart';
import 'models/license_model.dart';
import 'features/license/screens/license_import_screen.dart';
import 'core/app_strings.dart';
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
import 'providers/developer_provider.dart';
import 'features/mgmt/developer_mgmt_screen.dart';
import 'features/settings/telegram_settings_screen.dart';
import 'providers/user_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/expense_provider.dart';
import 'features/inventory/inventory_menu_screen.dart';
import 'features/mgmt/expenses_screen.dart';
import 'features/mgmt/customers_screen.dart';
import 'features/mgmt/cashiers_mgmt_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Window management setup
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
      // Don't show immediately if we want to avoid white flashes
      await windowManager.setBackgroundColor(Colors.black);
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setFullScreen(true);
    });

    // 2. Initialize Core Services (Database, License)
    // If these fail, we catch and show error screen
    await DatabaseHelper.instance.database;
    await LicenseService.instance.init();

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
          ChangeNotifierProvider(
            create: (_) => WaiterProvider()..loadWaiters(),
          ),
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
          ChangeNotifierProvider(
            create: (_) => InventoryProvider()..loadIngredients(),
          ),
          ChangeNotifierProvider.value(value: LicenseService.instance),
        ],
        child: const TezzroApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('FATAL STARTUP ERROR: $e');
    debugPrint(stack.toString());

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: BootstrapErrorApp(error: e.toString()),
      ),
    );
  }
}

class BootstrapErrorApp extends StatelessWidget {
  final String error;
  const BootstrapErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Tizimni ishga tushirishda xatolik',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ilovani ishga tushirishda texnik muammo yuzaga keldi. Iltimos, administratorga murojaat qiling.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => exit(0),
                icon: const Icon(Icons.close),
                label: const Text('Ilovani yopish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TezzroApp extends StatelessWidget {
  const TezzroApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppStrings.setLanguage('uz');

    return ScreenUtilInit(
      designSize: const Size(1280, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final licenseService = context.watch<LicenseService>();
        final appSettings = context.watch<AppSettingsProvider>();
        final status = licenseService.currentStatus;

        return MaterialApp(
          title: 'ZELLY',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appSettings.themeMode,
          home: _getHome(status),
        );
      },
    );
  }

  Widget _getHome(LicenseStatus status) {
    // Agar litsenziya faol bo'lsa yoki imtiyozli davrda bo'lsa - Login sahifasiga
    if (status.isValid) {
      return const UpdateCheckWrapper(child: LoginScreen());
    }

    // Agar litsenziya muddati tugagan bo'lsa, lekin import sahifasiga kirish ruxsat berilgan bo'lsa
    // Bu yerda foydalanuvchi hisobotlarni ko'rishi ham mumkin (talab bo'yicha),
    // lekin biz to'g'ridan-to'g'ri aktivatsiya o'rniga litsenziya oynasini ko'rsatamiz.
    return const UpdateCheckWrapper(child: LicenseImportScreen());
  }
}

class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;

  const UpdateCheckWrapper({super.key, required this.child});

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    // Backgroundda tekshirish
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        final updateInfo = await UpdateService.checkForUpdates();
        if (updateInfo != null) {
          UpdateService.showUpdateDialog(context, updateInfo);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
            // Force reload for non-admin/non-cashier local users if server IP exists
            final forceRemote =
                user['role'] != 'admin' && user['role'] != 'cashier';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
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
                  Text(
                    'Tizimga kirish uchun PIN kodni kiriting',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 16,
                    ),
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
                              ? theme.colorScheme.primary
                              : (isDark
                                    ? Colors.white10
                                    : const Color(0xFFF1F5F9)),
                          border: Border.all(
                            color: _enteredPin.length > index
                                ? theme.colorScheme.primary
                                : (isDark
                                      ? Colors.white24
                                      : const Color(0xFFE2E8F0)),
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
                        ].map((n) => _buildPinButton(context, n)),
                        _buildPinButton(
                          context,
                          'C',
                          color: Colors.orange.shade50,
                          textColor: Colors.orange.shade700,
                        ),
                        _buildPinButton(context, '0'),
                        _buildPinButton(
                          context,
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
                color: theme.colorScheme.surface,
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

  Widget _buildPinButton(
    BuildContext context,
    String text, {
    Color? color,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color:
          color ??
          (isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC)),
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
              color: textColor ?? theme.colorScheme.onSurface,
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
    const InventoryMenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<AppSettingsProvider>(); // Watch for language changes
    final connectivity = context.watch<ConnectivityProvider>();
    final user = connectivity.currentUser;
    final role = user?['role'] ?? 'admin';

    // Sidebar always stays dark regardless of app theme (premium dark sidebar)
    const sidebarBg = Color(0xFF0F172A); // deep slate-900 — always dark
    const sidebarFg = Colors.white; // always white text/icons

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 250 : 70,
            color: sidebarBg,
            child: Column(
              children: [
                _buildSidebarHeader(sidebarFg),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    children: [
                      // Stollar - All roles can see
                      _buildSidebarItem(
                        0,
                        Icons.grid_view_outlined,
                        AppStrings.tablesNav,
                        sidebarFg,
                      ),

                      // Admin - sees everything
                      if (role == 'admin') ...[
                        _buildSidebarItem(
                          1,
                          Icons.inventory_2_outlined,
                          AppStrings.productsNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          2,
                          Icons.category_outlined,
                          AppStrings.categoriesNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          3,
                          Icons.layers_outlined,
                          AppStrings.locationsNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          4,
                          Icons.table_bar_outlined,
                          AppStrings.tablesSettingsNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          5,
                          Icons.people_outline,
                          AppStrings.waitersNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          13,
                          Icons.person_add_alt_1_outlined,
                          AppStrings.cashiersNav,
                          sidebarFg,
                        ),
                        Divider(
                          color: sidebarFg.withOpacity(0.1),
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader(AppStrings.finance, sidebarFg),
                        _buildSidebarItem(
                          14,
                          Icons.payments_outlined,
                          AppStrings.expensesNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          15,
                          Icons.groups_outlined,
                          AppStrings.customersNav,
                          sidebarFg,
                        ),
                        Divider(
                          color: sidebarFg.withOpacity(0.1),
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader(AppStrings.stats, sidebarFg),
                        _buildSidebarItem(
                          6,
                          Icons.bar_chart_rounded,
                          AppStrings.reportsNav,
                          sidebarFg,
                        ),
                        Divider(
                          color: sidebarFg.withOpacity(0.1),
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader('Sozlamalar', sidebarFg),
                        _buildSidebarItem(
                          7,
                          Icons.print_outlined,
                          AppStrings.printerNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          8,
                          Icons.receipt_long_outlined,
                          AppStrings.receiptNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          9,
                          Icons.lock_outline,
                          AppStrings.pinNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          10,
                          Icons.branding_watermark_outlined,
                          AppStrings.brandNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          11,
                          Icons.settings_ethernet_outlined,
                          AppStrings.connectionNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          12,
                          Icons.send_outlined,
                          AppStrings.telegramNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          16,
                          Icons.warehouse_outlined,
                          'Ombor',
                          sidebarFg,
                        ),
                      ],

                      // Cashier - limited access
                      if (role == 'cashier') ...[
                        _buildSidebarItem(
                          1,
                          Icons.inventory_2_outlined,
                          AppStrings.productsNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          2,
                          Icons.category_outlined,
                          AppStrings.categoriesNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          3,
                          Icons.layers_outlined,
                          AppStrings.locationsNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          4,
                          Icons.table_bar_outlined,
                          AppStrings.tablesSettingsNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          5,
                          Icons.people_outline,
                          AppStrings.waitersNav,
                          sidebarFg,
                        ),
                        Divider(
                          color: sidebarFg.withOpacity(0.1),
                          height: 32,
                          indent: 20,
                          endIndent: 20,
                        ),
                        _buildSectionHeader('Sozlamalar', sidebarFg),
                        _buildSidebarItem(
                          7,
                          Icons.print_outlined,
                          AppStrings.printerNav,
                          sidebarFg,
                        ),
                        _buildSidebarItem(
                          8,
                          Icons.receipt_long_outlined,
                          AppStrings.receiptNav,
                          sidebarFg,
                        ),
                      ],

                      // Waiter - only tables (already shown above)
                    ],
                  ),
                ),
                _buildSidebarBottom(user, role, sidebarFg),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            Expanded(
              child: GestureDetector(
                onLongPress: () async {
                  final passwordController = TextEditingController();
                  final correct = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Developer Access'),
                      content: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Parolni kiriting',
                          hintText: 'Password',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Bekor qilish'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (passwordController.text == 'DEVELOPER2026') {
                              Navigator.pop(context, true);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Parol noto\'g\'ri!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: const Text('Kirish'),
                        ),
                      ],
                    ),
                  );

                  if (correct == true && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeveloperMgmtScreen(),
                      ),
                    );
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZELLY',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'POS tizimi',
                      style: TextStyle(
                        color: color.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Theme toggle — always visible
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: color.withOpacity(0.6),
              size: 20,
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () {
              context.read<AppSettingsProvider>().setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          if (_isExpanded) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    if (!_isExpanded) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color.withOpacity(0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label,
    Color color,
  ) {
    final bool active = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withOpacity(0.05),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active ? color.withOpacity(0.1) : Colors.transparent,
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
                  color: active
                      ? AppTheme.secondaryColor
                      : color.withOpacity(0.6),
                  size: 22,
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? color : color.withOpacity(0.6),
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

  Widget _buildSidebarBottom(
    Map<String, dynamic>? user,
    String role,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.05)),
      child: Column(
        children: [
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: color.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['name'] ?? 'Admin',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          role == 'admin' ? 'Admin' : 'Kassir',
                          style: TextStyle(
                            color: color.withOpacity(0.3),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.logout,
                      size: 18,
                      color: color.withOpacity(0.3),
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
                  color: color.withOpacity(0.3),
                  size: 20,
                ),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
              if (_isExpanded)
                Text(
                  'v1.0.2',
                  style: TextStyle(color: color.withOpacity(0.1), fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

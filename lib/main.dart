import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/utils/keyboard_utils.dart';
import 'core/database_helper.dart';
import 'core/services/license_service.dart';
import 'core/update_service.dart';
import 'models/license_model.dart';
import 'features/license/screens/license_import_screen.dart';
import 'core/app_strings.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/category_provider.dart';
import 'providers/location_provider.dart';
import 'providers/table_provider.dart';
import 'providers/waiter_provider.dart';
import 'providers/report_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/receipt_settings_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/developer_provider.dart';
import 'providers/user_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/expense_provider.dart';
import 'features/login/login_screen.dart';

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
      await windowManager.setBackgroundColor(Colors.black);
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setFullScreen(true);
    });

    // 2. Initialize Core Services (Database, License)
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

class TezzroApp extends StatefulWidget {
  const TezzroApp({super.key});

  @override
  State<TezzroApp> createState() => _TezzroAppState();
}

class _TezzroAppState extends State<TezzroApp> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final focused = FocusManager.instance.primaryFocus != null &&
        FocusManager.instance.primaryFocus!.context != null;
    if (focused != _hasFocus) {
      setState(() => _hasFocus = focused);
    }
  }

  void _dismissKeyboard() {
    KeyboardUtils.dismiss();
  }

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
          // Touchscreen monobloklarda: textfield tashqarisiga bosganda
          // klaviatura yopilishi va focus tushishi uchun global handler
          builder: (context, child) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissKeyboard,
              child: Stack(
                children: [
                  child!,
                  // Windows touch klaviaturasi uchun: focus bo'lganda
                  // ekranning o'ng pastida "Klaviaturani yopish" tugmasi
                  if (_hasFocus)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _dismissKeyboard,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_hide_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Yopish',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          home: _getHome(status),
        );
      },
    );
  }

  Widget _getHome(LicenseStatus status) {
    if (status.isValid) {
      return const UpdateCheckWrapper(child: LoginScreen());
    }
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

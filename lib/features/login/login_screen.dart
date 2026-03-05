import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database_helper.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/waiter_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/customer_provider.dart';
import '../main_layout/main_layout.dart';
import '../../features/settings/connection_settings_screen.dart';

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Left: Numpad
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 80,
                  vertical: 40,
                ),
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
                              isClient ? 'Ofitsiant Tizimi' : 'Xush kelibsiz',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (connectivity.lastError != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  connectivity.lastError!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tizimga kirish uchun shaxsiy PIN kodni kiriting',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // PIN Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _enteredPin.length > index
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.1),
                            boxShadow: _enteredPin.length > index
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Numpad
                    SizedBox(
                      width: 320,
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1.1,
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
                            color: const Color(0xFFF1F5F9),
                            textColor: const Color(0xFF64748B),
                          ),
                          _buildPinButton(context, '0'),
                          _buildPinButton(
                            context,
                            '⌫',
                            color: const Color(0xFFFEF2F2),
                            textColor: const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
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
                      icon: const Icon(
                        Icons.settings_input_component_rounded,
                        size: 18,
                      ),
                      label: const Text('Ulanish sozlamalari'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
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
                color: const Color(0xFF0F172A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(10, 10),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: settings.brandImagePath != null
                        ? Image.file(
                            File(settings.brandImagePath!),
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            'assets/images/login_default.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFF1E293B)),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.restaurantName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Text(
                            'Smart POS & Business Automation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          color ?? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _handlePinPress(text),
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

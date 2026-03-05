import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_strings.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/cart_provider.dart';
import '../../features/pos/tables_screen.dart';
import '../../features/mgmt/products_mgmt_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/mgmt/categories_mgmt_screen.dart';
import '../../features/mgmt/printer_settings_screen.dart';
import '../../features/mgmt/locations_mgmt_screen.dart';
import '../../features/mgmt/tables_mgmt_screen.dart';
import '../../features/mgmt/waiters_mgmt_screen.dart';
import '../../features/mgmt/cashiers_mgmt_screen.dart';
import '../../features/mgmt/expenses_screen.dart';
import '../../features/mgmt/customers_screen.dart';
import '../../features/inventory/inventory_menu_screen.dart';
import '../../features/settings/receipt_settings_screen.dart';
import '../../features/settings/pin_settings_screen.dart';
import '../../features/settings/brand_settings_screen.dart';
import '../../features/settings/connection_settings_screen.dart';
import '../../features/settings/telegram_settings_screen.dart';
import '../../features/mgmt/developer_mgmt_screen.dart';
import '../login/login_screen.dart';
import './widgets/menu_dialog.dart';

class MainLayout extends StatefulWidget {
  final int? initialIndex;
  const MainLayout({super.key, this.initialIndex});

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }

  void setIndex(int index) {
    setState(() => _selectedIndex = index);
  }

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
    final isCashier = role == 'cashier';

    // Sidebar always stays dark regardless of app theme (premium dark sidebar)
    const sidebarBg = Color(0xFF0F172A); // deep slate-900 — always dark
    const sidebarFg = Colors.white; // always white text/icons

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          if (!isCashier)
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
                          if (context.read<CartProvider>().hasPermission(
                            context,
                            'perm_manage_expenses',
                          ))
                            _buildSidebarItem(
                              14,
                              Icons.payments_outlined,
                              AppStrings.expensesNav,
                              sidebarFg,
                            ),
                          if (context.read<CartProvider>().hasPermission(
                            context,
                            'perm_view_reports',
                          ))
                            Column(
                              children: [
                                Divider(
                                  color: sidebarFg.withOpacity(0.1),
                                  height: 32,
                                  indent: 20,
                                  endIndent: 20,
                                ),
                                _buildSectionHeader(
                                  AppStrings.stats,
                                  sidebarFg,
                                ),
                                _buildSidebarItem(
                                  6,
                                  Icons.bar_chart_rounded,
                                  AppStrings.reportsNav,
                                  sidebarFg,
                                ),
                              ],
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (child, previousChildren) {
                  return Stack(
                    children: [...previousChildren, if (child != null) child],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints.expand(),
                    child: _screens[_selectedIndex],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isCashier
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => NavigationMenuDialog(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                );
              },
              backgroundColor: const Color(0xFF6366F1),
              elevation: 4,
              child: const Icon(Icons.menu, color: Colors.white),
            )
          : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: active ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withOpacity(0.08),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 8,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: active
                      ? color
                      : color.withOpacity(_isExpanded ? 0.4 : 0.6),
                  size: 24,
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? color : color.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                ],
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

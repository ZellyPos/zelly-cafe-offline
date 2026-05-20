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
import '../../features/mgmt/couriers_mgmt_screen.dart';
import '../../features/mgmt/delivery_zones_screen.dart';
import '../../features/delivery/delivery_screen.dart';
import '../login/login_screen.dart';
import './widgets/menu_dialog.dart';
import '../../providers/shift_provider.dart';
import '../shift/screens/shift_hub_screen.dart';
import '../saboy/saboy_orders_screen.dart';

const _kAccent = Color(0xFF6366F1);
const _kSidebarBg = Color(0xFF0F172A);
const _kSidebarFg = Colors.white;

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

  void setIndex(int index) => setState(() => _selectedIndex = index);

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
    const ShiftHubScreen(),        // 17
    const DeliveryScreen(),        // 18
    const CouriersMgmtScreen(),    // 19
    const DeliveryZonesScreen(),   // 20
    const SaboyOrdersScreen(),     // 21
  ];

  void _logout() {
    context.read<ConnectivityProvider>().setCurrentUser(null);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openDevScreen() async {
    final correct = await showDialog<bool>(
      context: context,
      builder: (_) => const _DevPinDialog(),
    );
    if (correct == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeveloperMgmtScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppSettingsProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final user = connectivity.currentUser;
    final role = user?['role'] ?? 'admin';
    final isCashier = role == 'cashier';

    return Scaffold(
      body: Row(
        children: [
          if (!isCashier) _buildSidebar(user, role),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (child, previousChildren) =>
                    Stack(children: [...previousChildren, ?child]),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
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
              onPressed: () => showDialog(
                context: context,
                builder: (_) => NavigationMenuDialog(
                  selectedIndex: _selectedIndex,
                  onItemSelected: (i) => setState(() => _selectedIndex = i),
                ),
              ),
              backgroundColor: _kAccent,
              elevation: 4,
              child: const Icon(Icons.menu, color: Colors.white),
            )
          : null,
    );
  }

  // ─── Sidebar ────────────────────────────────────────────────────────────────

  Widget _buildSidebar(Map<String, dynamic>? user, String role) {
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          width: _isExpanded ? 240 : 68,
          color: _kSidebarBg,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  children: _buildNavItems(role),
                ),
              ),
              _buildBottom(user, role),
            ],
          ),
        ),
        // Hover-strip: right edge expand button shown when collapsed
        if (!_isExpanded)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _isExpanded = true),
                child: Container(width: 10, color: Colors.transparent),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Header with toggle ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // When collapsed: entire header is one big tap target to expand
    if (!_isExpanded) {
      return Tooltip(
        message: 'Panelni ochish',
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isExpanded = true),
            child: SizedBox(
              height: 68,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      color: _kAccent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded header
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _kSidebarFg.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Logo mark — long press → dev screen
          GestureDetector(
            onLongPress: _openDevScreen,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.bolt_rounded, color: _kAccent, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZELLY',
                  style: TextStyle(
                    color: _kSidebarFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'POS tizimi',
                  style: TextStyle(
                    color: _kSidebarFg.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Theme toggle
          _IconBtn(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: isDark ? 'Kunduzgi rejim' : 'Tungi rejim',
            onTap: () => context.read<AppSettingsProvider>().setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
          const SizedBox(width: 4),
          // Collapse toggle
          _IconBtn(
            icon: Icons.keyboard_double_arrow_left_rounded,
            tooltip: 'Yopish',
            onTap: () => setState(() => _isExpanded = false),
          ),
        ],
      ),
    );
  }

  // ─── Navigation items builder ───────────────────────────────────────────────

  List<Widget> _buildNavItems(String role) {
    final enableInventory = context.read<AppSettingsProvider>().enableInventory;
    final cartProv = context.read<CartProvider>();

    final canExpenses = cartProv.hasPermission(context, 'perm_manage_expenses');
    final canReports = cartProv.hasPermission(context, 'perm_view_reports');

    if (role == 'admin') {
      return [
        // POS
        _item(0, Icons.grid_view_rounded, AppStrings.tablesNav),
        _item(21, Icons.shopping_bag_outlined, 'Saboy'),

        _divider(),
        _section('Boshqaruv'),
        _item(1, Icons.inventory_2_outlined, AppStrings.productsNav),
        _item(2, Icons.category_outlined, AppStrings.categoriesNav),
        _item(3, Icons.layers_outlined, AppStrings.locationsNav),
        _item(4, Icons.table_bar_outlined, AppStrings.tablesSettingsNav),
        _item(5, Icons.badge_outlined, AppStrings.waitersNav),
        _item(13, Icons.manage_accounts_outlined, AppStrings.cashiersNav),
        _item(19, Icons.delivery_dining_outlined, 'Kuryerlar'),
        _item(20, Icons.map_outlined, 'Yetkazish zonalari'),

        _divider(),
        _section('Moliya'),
        _shiftStatusTile(),
        _item(17, Icons.work_history_rounded, 'Smena'),
        _item(14, Icons.payments_outlined, AppStrings.expensesNav),
        _item(15, Icons.groups_outlined, AppStrings.customersNav),

        _divider(),
        _section('Hisobot'),
        _item(6, Icons.bar_chart_rounded, AppStrings.reportsNav),

        _divider(),
        _section('Sozlamalar'),
        _item(7, Icons.print_outlined, AppStrings.printerNav),
        _item(8, Icons.receipt_long_outlined, AppStrings.receiptNav),
        _item(9, Icons.lock_outline_rounded, AppStrings.pinNav),
        _item(10, Icons.branding_watermark_outlined, AppStrings.brandNav),
        _item(11, Icons.settings_ethernet_outlined, AppStrings.connectionNav),
        _item(12, Icons.send_outlined, AppStrings.telegramNav),
        if (enableInventory) _item(16, Icons.warehouse_outlined, 'Ombor'),
      ];
    }

    // Waiter — faqat stollar
    if (role == 'waiter') {
      return [
        _item(0, Icons.grid_view_rounded, AppStrings.tablesNav),
      ];
    }

    // Cashier
    return [
      _item(0, Icons.grid_view_rounded, AppStrings.tablesNav),

      _divider(),
      _section('Boshqaruv'),
      _item(1, Icons.inventory_2_outlined, AppStrings.productsNav),
      _item(2, Icons.category_outlined, AppStrings.categoriesNav),
      _item(3, Icons.layers_outlined, AppStrings.locationsNav),
      _item(4, Icons.table_bar_outlined, AppStrings.tablesSettingsNav),
      _item(5, Icons.badge_outlined, AppStrings.waitersNav),

      if (canExpenses) ...[
        _divider(),
        _section('Moliya'),
        _item(14, Icons.payments_outlined, AppStrings.expensesNav),
      ],

      if (canReports) ...[
        _divider(),
        _section(AppStrings.stats),
        _item(6, Icons.bar_chart_rounded, AppStrings.reportsNav),
      ],

      _divider(),
      _section('Sozlamalar'),
      _item(7, Icons.print_outlined, AppStrings.printerNav),
      _item(8, Icons.receipt_long_outlined, AppStrings.receiptNav),
    ];
  }

  // ─── Single nav item ────────────────────────────────────────────────────────

  Widget _item(int index, IconData icon, String label) {
    final active = _selectedIndex == index;

    Widget tile = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 10 : 8,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: _kSidebarFg.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: active
                  ? _kAccent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: active ? _kAccent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 10 : 0,
              vertical: 11,
            ),
            child: Row(
              mainAxisAlignment: _isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: active ? _kAccent : _kSidebarFg.withValues(alpha: 0.5),
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? _kSidebarFg
                            : _kSidebarFg.withValues(alpha: 0.65),
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!_isExpanded) {
      return Tooltip(
        message: label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }
    return tile;
  }

  // ─── Section label ──────────────────────────────────────────────────────────

  Widget _section(String title) {
    if (!_isExpanded) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: _kSidebarFg.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  // ─── Smena: live status tile ────────────────────────────────────────────────

  Widget _shiftStatusTile() {
    final shiftProvider = context.watch<ShiftProvider>();
    final shift = shiftProvider.activeShift;
    final summary = shiftProvider.liveSummary;

    if (!_isExpanded) {
      // Collapsed: faqat rangli dot
      return Tooltip(
        message: shift != null ? 'Smena ochiq' : 'Smena yopiq',
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: shift != null
                    ? const Color(0xFF10B981)
                    : Colors.red.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    if (shift == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Smena yopiq',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final elapsed = shiftProvider.elapsedTime;
    final elapsedStr = '${elapsed.inHours}s ${elapsed.inMinutes % 60}d';
    final salesStr = summary != null ? _fmtAmount(summary.totalSales) : '—';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Smena ochiq',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '#${shift.id}',
                style: TextStyle(
                  color: _kSidebarFg.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _miniStat(Icons.access_time_rounded, elapsedStr),
              const SizedBox(width: 10),
              _miniStat(Icons.payments_outlined, salesStr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _kSidebarFg.withValues(alpha: 0.35)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: _kSidebarFg.withValues(alpha: 0.55),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  // ─── Smena: ochish/kassa harakati action item ────────────────────────────────

  Widget _divider() => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: _isExpanded ? 16 : 12,
      vertical: 6,
    ),
    child: Divider(color: _kSidebarFg.withValues(alpha: 0.07), height: 1),
  );

  // ─── Bottom: user + logout ──────────────────────────────────────────────────

  Widget _buildBottom(Map<String, dynamic>? user, String role) {
    final name = user?['name'] ?? 'Admin';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final roleLabel = role == 'admin' ? 'Admin' : 'Kassir';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _kSidebarFg.withValues(alpha: 0.07)),
        ),
      ),
      child: _isExpanded
          ? Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _kSidebarFg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        roleLabel,
                        style: TextStyle(
                          color: _kSidebarFg.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _IconBtn(
                  icon: Icons.logout_rounded,
                  tooltip: 'Chiqish',
                  onTap: _logout,
                ),
              ],
            )
          : Tooltip(
              message: 'Chiqish',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _logout,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: _kSidebarFg.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── Small icon button helper ────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 18,
              color: _kSidebarFg.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Developer PIN dialog ────────────────────────────────────────────────────

class _DevPinDialog extends StatefulWidget {
  const _DevPinDialog();

  @override
  State<_DevPinDialog> createState() => _DevPinDialogState();
}

class _DevPinDialogState extends State<_DevPinDialog> {
  String _pin = '';
  bool _error = false;

  static const _correctPin = '2026';

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = false;
    });
    if (_pin.length == 4) Future.microtask(_check);
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = false;
    });
  }

  void _check() {
    if (_pin == _correctPin) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _pin = '';
        _error = true;
      });
    }
  }

  Widget _key(String k, ThemeData t) {
    final isDel = k == '⌫';
    return SizedBox(
      width: 60,
      height: 48,
      child: TextButton(
        onPressed: isDel ? _onDelete : () => _onKey(k),
        style: TextButton.styleFrom(
          backgroundColor: isDel
              ? t.colorScheme.error.withValues(alpha: 0.08)
              : t.colorScheme.surfaceContainerHighest,
          foregroundColor: isDel
              ? t.colorScheme.error
              : t.colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          k,
          style: TextStyle(
            fontSize: isDel ? 18 : 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 260,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 18,
                    color: t.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Developer',
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error
                          ? t.colorScheme.error
                          : filled
                          ? t.colorScheme.primary
                          : t.colorScheme.outline.withValues(alpha: 0.25),
                      border: Border.all(
                        color: _error
                            ? t.colorScheme.error
                            : filled
                            ? t.colorScheme.primary
                            : t.colorScheme.outline.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: _error
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Noto\'g\'ri PIN',
                          style: TextStyle(
                            color: t.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', '⌫'],
              ]) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: row
                      .map(
                        (k) => k.isEmpty
                            ? const SizedBox(width: 60, height: 48)
                            : _key(k, t),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/table.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/app_strings.dart';
import 'pos_screen.dart';
import 'widgets/floor_plan_viewer.dart';
import 'widgets/floor_plan_editor.dart';
import '../login/login_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  int? _selectedLocationId;
  Timer? _refreshTimer;
  bool _isFloorPlanView = false;
  bool _isDesignMode = false;

  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityProvider>();
    final locations = context.read<LocationProvider>().locations;
    if (locations.isNotEmpty) {
      _selectedLocationId = locations.first.id;
    }

    // Initial load with loading indicator (after build completes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TableProvider>().loadTables(
        connectivity: connectivity,
        silent: false,
      );
    });

    // Polling interval: 1 second for real-time updates (silent)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Silent update - no loading indicator, no setState
        context.read<TableProvider>().loadTables(
          connectivity: connectivity,
          silent: true,
        );
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = context.watch<TableProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final currentUser = connectivity.currentUser;
    final role = currentUser?['role'] ?? 'admin';
    final userId = currentUser?['id'];

    if (_selectedLocationId == null && locationProvider.locations.isNotEmpty) {
      _selectedLocationId = locationProvider.locations.first.id;
    }

    // Filter by location first
    var filteredTables = tableProvider.tables.where(
      (t) => t.locationId == _selectedLocationId,
    );

    // Filter for waiters - show only their tables and empty tables
    if (role == 'waiter' && userId != null) {
      filteredTables = filteredTables.where((t) {
        // Show empty tables (available for waiter to open)
        if (t.status == 0) return true;
        // Show occupied tables assigned to this waiter
        if (t.status == 1 && t.activeOrder?.waiterId == userId) return true;
        return false;
      });
    }

    final tables = filteredTables.toList();

    // Map of activeOrderId -> List of Tables in that order (Joined tables)
    final joinGroups = <String, List<TableModel>>{};
    for (var t in tableProvider.tables) {
      if (t.activeOrderId != null) {
        joinGroups.putIfAbsent(t.activeOrderId!, () => []).add(t);
      }
    }
    // Only keep groups with > 1 table
    joinGroups.removeWhere((key, value) => value.length < 2);

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Navigation
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildLocationTabs(context, locationProvider),
                  ),
                  const SizedBox(width: 16),
                  _buildViewToggle(context),
                  const SizedBox(width: 12),
                  if (role == 'admin') ...[
                    _buildDesignToggle(context),
                    const SizedBox(width: 12),
                  ],
                  if (role == 'cashier') ...[
                    _buildLogoutButton(context),
                    const SizedBox(width: 12),
                  ],
                  _buildSaboyButton(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: tableProvider.isLoading && tableProvider.tables.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _isFloorPlanView
                  ? (_isDesignMode
                        ? FloorPlanEditor(
                            tables: tables,
                            locationId: _selectedLocationId!,
                          )
                        : FloorPlanViewer(
                            tables: tables,
                            joinGroups: joinGroups,
                            onTableTap: (table) =>
                                _handleTableTap(context, table),
                          ))
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width >= 1600
                            ? 8
                            : (MediaQuery.of(context).size.width >= 1200
                                  ? 6
                                  : (MediaQuery.of(context).size.width >= 1000
                                        ? 5
                                        : 4)),
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: tables.length,
                      itemBuilder: (context, index) {
                        final table = tables[index];
                        final joinedWith = table.activeOrderId != null
                            ? joinGroups[table.activeOrderId!]
                            : null;
                        return _buildTableCard(context, table, joinedWith);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTabs(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    if (locationProvider.locations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
      ),
      padding: const EdgeInsets.all(4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locationProvider.locations.length,
        itemBuilder: (context, index) {
          final loc = locationProvider.locations[index];
          final isSelected = _selectedLocationId == loc.id;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedLocationId = loc.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  loc.name,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaboyButton(BuildContext context) {
    return Container(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PosScreen(orderType: 1),
            ),
          );
        },
        icon: const Icon(Icons.shopping_bag_outlined, size: 20),
        label: Text(
          AppStrings.saboy.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    TableModel table, [
    List<TableModel>? joinedWith,
  ]) {
    final theme = Theme.of(context);
    final isOccupied = table.status == 1;
    final info = table.activeOrder;
    final bool isJoined = joinedWith != null && joinedWith.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTableTap(context, table),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        table.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isJoined)
                      _buildJoinBadge()
                    else
                      _buildStatusBadge(isOccupied),
                  ],
                ),
                if (isJoined)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      "Birlashgan: ${joinedWith.where((t) => t.id != table.id).map((t) => t.name).join(', ')}",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 12),
                if (isOccupied && info != null) ...[
                  _buildIconText(
                    context,
                    Icons.person_outline_rounded,
                    info.waiterName ?? "Kassa",
                  ),
                  const SizedBox(height: 6),
                  if (table.pricingType == 1)
                    _buildIconText(
                      context,
                      Icons.timer_outlined,
                      _formatDuration(info.openedAt),
                      color: Colors.orange.shade700,
                    ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${PriceFormatter.format(info.totalAmount)} so'm",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                  Center(
                    child: Icon(
                      Icons.table_bar_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurface.withOpacity(0.05),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppStrings.tableEmpty,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _buildIconText(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor =
        color ?? theme.colorScheme.onSurface.withOpacity(0.6);
    return Row(
      children: [
        Icon(icon, size: 16, color: effectiveColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 14,
              inherit: true,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool occupied) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: occupied
            ? const Color(0xFFFEF2F2) // Red 50
            : const Color(0xFFECFDF5), // Emerald 50
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        occupied ? AppStrings.occupied : AppStrings.available,
        style: TextStyle(
          color: occupied
              ? const Color(0xFFEF4444) // Red 500
              : const Color(0xFF10B981), // Emerald 500
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildJoinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Blue 50
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_rounded, size: 12, color: Color(0xFF3B82F6)),
          const SizedBox(width: 4),
          const Text(
            "Birlashgan",
            style: TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IconButton(
        onPressed: () => setState(() => _isFloorPlanView = !_isFloorPlanView),
        icon: Icon(
          _isFloorPlanView ? Icons.grid_view_rounded : Icons.map_outlined,
          color: theme.colorScheme.primary,
          size: 22,
        ),
        tooltip: _isFloorPlanView
            ? 'Grid ko\'rinishi'
            : 'Floor Plan ko\'rinishi',
      ),
    );
  }

  Widget _buildDesignToggle(BuildContext context) {
    if (!_isFloorPlanView) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _isDesignMode ? Colors.orange : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDesignMode ? Colors.orange : const Color(0xFFE2E8F0),
        ),
      ),
      child: IconButton(
        onPressed: () => setState(() => _isDesignMode = !_isDesignMode),
        icon: Icon(
          _isDesignMode ? Icons.check_rounded : Icons.design_services_rounded,
          color: _isDesignMode ? Colors.white : Colors.orange,
          size: 22,
        ),
        tooltip: _isDesignMode ? 'Saqlash' : 'Dizayn rejimi',
      ),
    );
  }

  String _formatDuration(DateTime? start) {
    if (start == null) return "0 ${AppStrings.minutesShort}";
    final diff = DateTime.now().difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0
        ? "$h ${AppStrings.hoursShort} $m ${AppStrings.minutesShortLabel}"
        : "$m ${AppStrings.minutesShortLabel}";
  }

  void _handleTableTap(BuildContext context, TableModel table) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PosScreen(orderType: 0, table: table),
          ),
        )
        .then((_) {
          context.read<TableProvider>().loadTables();
        });
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444), // Red 500
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Chiqish'),
              content: const Text('Rostdan ham tizimdan chiqmoqchimisiz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bekor qilish'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<ConnectivityProvider>().setCurrentUser(null);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Chiqish',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
        tooltip: 'Tizimdan chiqish',
      ),
    );
  }
}

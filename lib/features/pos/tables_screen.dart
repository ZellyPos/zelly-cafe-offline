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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildLocationTabs(context, locationProvider)),
                const SizedBox(width: 16),
                _buildViewToggle(context),
                const SizedBox(width: 16),
                if (role == 'admin') ...[
                  _buildDesignToggle(context),
                  const SizedBox(width: 16),
                ],
                _buildSaboyButton(context),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width >= 1600
                            ? 8
                            : (MediaQuery.of(context).size.width >= 1200
                                  ? 6
                                  : (MediaQuery.of(context).size.width >= 1000
                                        ? 5
                                        : 4)),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95,
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
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTabs(
    BuildContext context,
    LocationProvider locationProvider,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locationProvider.locations.length,
        itemBuilder: (context, index) {
          final loc = locationProvider.locations[index];
          final isSelected = _selectedLocationId == loc.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(loc.name),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedLocationId = loc.id),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: theme.colorScheme.surface,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                inherit: true,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaboyButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PosScreen(orderType: 1),
          ),
        );
      },
      icon: const Icon(Icons.shopping_bag_outlined),
      label: Text(
        AppStrings.saboy,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          inherit: true,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOccupied
              ? (isJoined
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.red.withOpacity(0.3))
              : theme.dividerColor.withOpacity(0.3),
          width: isJoined ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isJoined
                ? Colors.blue.withOpacity(0.05)
                : theme.shadowColor.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTableTap(context, table),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          inherit: true,
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
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Birlashgan: ${joinedWith.where((t) => t.id != table.id).map((t) => t.name).join(', ')}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        inherit: true,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                if (isOccupied && info != null) ...[
                  _buildIconText(
                    context,
                    Icons.person_outline,
                    info.waiterName ?? "Kassa",
                  ),
                  if (table.pricingType == 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: _buildIconText(
                        context,
                        Icons.timer_outlined,
                        _formatDuration(info.openedAt),
                        color: Colors.orange,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    "${PriceFormatter.format(info.totalAmount)} so'm",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      inherit: true,
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.table_bar_outlined,
                          size: 36,
                          color: Colors.green.withOpacity(0.1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.tableEmpty,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 12,
                            inherit: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
                const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: occupied
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        occupied ? AppStrings.occupied : AppStrings.available,
        style: TextStyle(
          color: occupied ? Colors.red.shade700 : Colors.green.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          inherit: true,
        ),
      ),
    );
  }

  Widget _buildJoinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 12, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            "Birlashgan",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              inherit: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => setState(() => _isFloorPlanView = !_isFloorPlanView),
        icon: Icon(
          _isFloorPlanView ? Icons.grid_view : Icons.map_outlined,
          color: AppTheme.primaryColor,
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
      decoration: BoxDecoration(
        color: _isDesignMode ? Colors.orange : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => setState(() => _isDesignMode = !_isDesignMode),
        icon: Icon(
          _isDesignMode ? Icons.check : Icons.design_services,
          color: _isDesignMode ? Colors.white : Colors.orange,
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
}

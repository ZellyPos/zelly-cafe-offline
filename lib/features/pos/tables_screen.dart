import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/location.dart';
import '../../providers/connectivity_provider.dart';
import '../../core/services/ws_client_service.dart';
import '../../core/server/websocket_manager.dart';
import '../../models/table.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/app_strings.dart';
import 'pos_screen.dart';
import 'widgets/floor_plan_viewer.dart';
import 'widgets/floor_plan_editor.dart';
import '../login/login_screen.dart';
import '../delivery/delivery_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  int? _selectedLocationId;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _fallbackTimer;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TableProvider>().loadTables(
        connectivity: connectivity,
        silent: false,
      );
      _startRealtime(connectivity);
    });
  }

  void _startRealtime(ConnectivityProvider connectivity) {
    final Stream<Map<String, dynamic>> eventStream;

    if (connectivity.mode == ConnectivityMode.client) {
      // Client device: receive events pushed over the network from the server
      eventStream = WsClientService.instance.events;
    } else {
      // Server / local device: receive in-process broadcasts directly
      eventStream = WebSocketManager.instance.localEvents;
    }

    _wsSubscription = eventStream.listen((event) {
      final type = event['event'] as String?;
      if (!mounted) return;
      if (type == 'tables_updated' || type == 'order_updated') {
        context.read<TableProvider>().loadTables(
          connectivity: connectivity,
          silent: true,
        );
      }
    });

    // Fallback: 30s silent refresh (catches edge cases / reconnects)
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<TableProvider>().loadTables(
          connectivity: connectivity,
          silent: true,
        );
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = context.watch<TableProvider>();
    final locations = context.select<LocationProvider, List<Location>>(
      (p) => p.locations,
    );
    final role = context.select<ConnectivityProvider, String>(
      (p) => p.currentUser?['role'] ?? 'admin',
    );

    if (_selectedLocationId == null && locations.isNotEmpty) {
      _selectedLocationId = locations.first.id;
    }

    // Filter by location first
    var filteredTables = tableProvider.tables.where(
      (t) => t.locationId == _selectedLocationId,
    );

    final tables = filteredTables.toList();

    // Map of activeOrderId -> List of Tables in that order (Joined tables)
    // Deduplicate by table ID first to prevent duplicate rows (e.g. from stale DB
    // entries) from incorrectly marking a table as merged with itself.
    final uniqueTables = <int, TableModel>{};
    for (var t in tableProvider.tables) {
      if (t.id != null) uniqueTables[t.id!] = t;
    }
    final joinGroups = <String, List<TableModel>>{};
    for (var t in uniqueTables.values) {
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
                    child: _buildLocationTabs(context, locations),
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
                  if (role == 'waiter') ...[
                    _buildLockButton(context),
                    const SizedBox(width: 12),
                  ],
                  if (role != 'waiter') ...[
                    _buildDeliveryButton(context),
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
    List<Location> locations,
  ) {
    if (locations.isEmpty) return const SizedBox.shrink();

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
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final loc = locations[index];
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

  Widget _buildDeliveryButton(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeliveryScreen()),
          );
        },
        icon: const Icon(Icons.delivery_dining_rounded, size: 20),
        label: const Text(
          'YETKAZIB BERISH',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSaboyButton(BuildContext context) {
    return SizedBox(
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
    final bool billRequested = info?.billRequested ?? false;
    final bool isJoined = joinedWith != null && joinedWith.length > 1;
    final connectivity = context.read<ConnectivityProvider>();
    final role = connectivity.currentUser?['role'] ?? 'admin';
    final userId = connectivity.currentUser?['id'];
    final bool isBlockedForWaiter = role == 'waiter' &&
        isOccupied &&
        table.activeOrder?.waiterId != null &&
        table.activeOrder?.waiterId != userId;

    const green = Color(0xFF10B981);
    final isDark = theme.brightness == Brightness.dark;

    // Rang va chegara holat bo'yicha
    final Color cardColor;
    final Border? cardBorder;
    final Color onCard;

    if (isBlockedForWaiter) {
      // Boshqa ofisant stoli — ko'k
      cardColor = isDark ? const Color(0xFF1A2C4A) : const Color(0xFFDBEAFE);
      cardBorder = Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1.5);
      onCard = isDark ? Colors.white : const Color(0xFF1E3A5F);
    } else if (billRequested) {
      // Chek chiqarilgan — to'q yashil
      cardColor = isDark ? const Color(0xFF14532D) : const Color(0xFF16A34A);
      cardBorder = Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.9), width: 1.5);
      onCard = Colors.white;
    } else if (isOccupied) {
      // Band (chek chiqarilmagan) — to'q sariq
      cardColor = isDark ? const Color(0xFF3D2A00) : const Color(0xFFFEF08A);
      cardBorder = Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.8), width: 1.5);
      onCard = isDark ? Colors.white : const Color(0xFF713F12);
    } else {
      // Bo'sh stol — yashil maysa
      cardColor = isDark ? const Color(0xFF0F2A1E) : const Color(0xFFECFDF5);
      cardBorder = Border.all(color: green.withValues(alpha: 0.25), width: 1);
      onCard = theme.colorScheme.onSurface;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: AppTheme.softShadow,
        border: cardBorder,
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
                          color: onCard,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (billRequested)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_active_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('HISOB', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (isJoined)
                      _buildJoinBadge()
                    else
                      isBlockedForWaiter
                          ? _buildLockedBadge()
                          : _buildStatusBadge(isOccupied),
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
                    color: onCard.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 6),
                  _buildIconText(
                    context,
                    Icons.access_time_rounded,
                    _formatTime(info.openedAt),
                    color: billRequested ? Colors.white70 : Colors.blue.shade700,
                  ),
                  if (info.billRequestedAt != null) ...[
                    const SizedBox(height: 4),
                    _buildIconText(
                      context,
                      Icons.receipt_outlined,
                      "Chek: ${_formatTime(info.billRequestedAt)}",
                      color: billRequested ? Colors.white70 : Colors.orange.shade700,
                    ),
                  ],
                  const SizedBox(height: 4),
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
                      color: onCard.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${PriceFormatter.format(info.totalAmount)} so'm",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: onCard,
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
            ? const Color(0xFFFFCDD2) // Red 200
            : const Color(0xFFECFDF5), // Emerald 50
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        occupied ? AppStrings.occupied : AppStrings.available,
        style: TextStyle(
          color: occupied
              ? const Color(0xFFB91C1C) // Red 700
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

  Widget _buildLockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFBFDBFE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF1D4ED8)),
          SizedBox(width: 4),
          Text(
            'Boshqa ofisant',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
    final connectivity = context.read<ConnectivityProvider>();
    final role = connectivity.currentUser?['role'] ?? 'admin';
    final userId = connectivity.currentUser?['id'];

    // Block waiter from entering another waiter's occupied table
    if (role == 'waiter' &&
        table.status == 1 &&
        table.activeOrder?.waiterId != null &&
        table.activeOrder?.waiterId != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu stol boshqa ofitsiantga tegishli, kira olmaysiz'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final tableProvider = context.read<TableProvider>();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PosScreen(orderType: 0, table: table),
          ),
        )
        .then((_) {
          if (!mounted) return;
          tableProvider.loadTables(connectivity: connectivity, silent: true);
        });
  }

  Widget _buildLockButton(BuildContext context) {
    return Tooltip(
      message: 'Qulflash',
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF475569),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () {
            context.read<ConnectivityProvider>().setCurrentUser(null);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
          padding: EdgeInsets.zero,
        ),
      ),
    );
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

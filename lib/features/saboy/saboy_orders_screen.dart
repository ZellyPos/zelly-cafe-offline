import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/saboy_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/server/websocket_manager.dart';
import '../../core/services/ws_client_service.dart';
import '../pos/pos_screen.dart';

class SaboyOrdersScreen extends StatefulWidget {
  const SaboyOrdersScreen({super.key});

  @override
  State<SaboyOrdersScreen> createState() => _SaboyOrdersScreenState();
}

class _SaboyOrdersScreenState extends State<SaboyOrdersScreen> {
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _fallbackTimer;

  static const _accent = Color(0xFF6366F1);
  static const _green = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SaboyProvider>().loadOrders();
      _startRealtime();
    });
  }

  void _startRealtime() {
    final connectivity = context.read<ConnectivityProvider>();
    final Stream<Map<String, dynamic>> eventStream;

    if (connectivity.mode == ConnectivityMode.client) {
      eventStream = WsClientService.instance.events;
    } else {
      eventStream = WebSocketManager.instance.localEvents;
    }

    _wsSubscription = eventStream.listen((event) {
      final type = event['event'] as String?;
      if (!mounted) return;
      if (type == 'tables_updated' || type == 'order_updated') {
        context.read<SaboyProvider>().loadOrders();
      }
    });

    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<SaboyProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _openNewOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PosScreen(orderType: 1),
      ),
    ).then((_) {
      if (mounted) context.read<SaboyProvider>().loadOrders();
    });
  }

  void _openOrder(SaboyOrderSummary order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosScreen(orderType: 1, orderId: order.id),
      ),
    ).then((_) {
      if (mounted) context.read<SaboyProvider>().loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<SaboyProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(theme, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saboy buyurtmalari',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Consumer<SaboyProvider>(
                  builder: (_, p, _) => Text(
                    '${p.openOrders.length} ta ochiq',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openNewOrder,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Yangi buyurtma'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, SaboyProvider provider) {
    if (provider.openOrders.isEmpty && provider.closedOrders.isEmpty) {
      return _buildEmpty(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.openOrders.isNotEmpty) ...[
            _sectionTitle('Ochiq buyurtmalar', theme),
            const SizedBox(height: 12),
            _buildGrid(provider.openOrders, theme, isOpen: true),
            const SizedBox(height: 24),
          ],
          if (provider.closedOrders.isNotEmpty) ...[
            _sectionTitle('Yopilgan buyurtmalar', theme),
            const SizedBox(height: 12),
            _buildGrid(provider.closedOrders, theme, isOpen: false),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGrid(
    List<SaboyOrderSummary> orders,
    ThemeData theme, {
    required bool isOpen,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis = (constraints.maxWidth / 200).floor().clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: orders.length,
          itemBuilder: (context, i) => _buildCard(orders[i], theme, isOpen: isOpen),
        );
      },
    );
  }

  Widget _buildCard(SaboyOrderSummary order, ThemeData theme, {required bool isOpen}) {
    final elapsed = order.openedAt != null
        ? DateTime.now().difference(order.openedAt!)
        : null;

    final borderColor = isOpen ? _accent.withValues(alpha: 0.35) : Colors.transparent;
    final bgColor = isOpen
        ? _accent.withValues(alpha: 0.06)
        : theme.colorScheme.surface;

    return GestureDetector(
      onTap: isOpen ? () => _openOrder(order) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order number + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.dailyNumber != null ? '#${order.dailyNumber}' : '—',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isOpen
                        ? _accent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? _accent.withValues(alpha: 0.12)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOpen ? 'Ochiq' : 'Yopilgan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isOpen
                          ? _accent
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Total
            Text(
              "${PriceFormatter.format(order.grandTotal)} so'm",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isOpen
                    ? _green
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            // Items count + elapsed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.itemCount} ta taom',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                if (elapsed != null && isOpen)
                  Text(
                    _formatElapsed(elapsed),
                    style: TextStyle(
                      fontSize: 11,
                      color: elapsed.inMinutes > 45
                          ? Colors.red.withValues(alpha: 0.8)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      fontWeight: elapsed.inMinutes > 45
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
              ],
            ),
            if (order.waiterName != null) ...[
              const SizedBox(height: 4),
              Text(
                order.waiterName!,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}s ${d.inMinutes.remainder(60)}d';
    return '${d.inMinutes}d';
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'Saboy buyurtmalari yo\'q',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yangi buyurtma yaratish uchun tugmani bosing',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openNewOrder,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Yangi buyurtma'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

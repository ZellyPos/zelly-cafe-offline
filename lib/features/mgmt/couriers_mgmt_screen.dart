import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/courier.dart';
import '../../models/order.dart';
import '../../providers/delivery_provider.dart';

class CouriersMgmtScreen extends StatefulWidget {
  const CouriersMgmtScreen({super.key});

  @override
  State<CouriersMgmtScreen> createState() => _CouriersMgmtScreenState();
}

class _CouriersMgmtScreenState extends State<CouriersMgmtScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Kurierlar boshqaruvi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          Consumer<DeliveryProvider>(
            builder: (_, dp, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Yangilash',
              onPressed: dp.loadOrders,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ── Chap: Kurierlar ──────────────────────────────────────────────
          _CourierPanel(onCourierTap: (c) => _tabController.animateTo(1)),
          VerticalDivider(
            width: 1,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
          // ── O'ng: Delivery buyurtmalar ───────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _buildTabBar(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DeliveryTab(
                        key: const ValueKey('new'),
                        statusFilter: const {0},
                        emptyText: 'Yangi buyurtmalar yo\'q',
                        emptyIcon: Icons.inbox_rounded,
                      ),
                      _DeliveryTab(
                        key: const ValueKey('onway'),
                        statusFilter: const {1, 2},
                        emptyText: 'Yo\'ldagi buyurtmalar yo\'q',
                        emptyIcon: Icons.delivery_dining_outlined,
                      ),
                      _DeliveryTab(
                        key: const ValueKey('done'),
                        statusFilter: const {3},
                        emptyText: 'Yetkazilgan buyurtmalar yo\'q',
                        emptyIcon: Icons.check_circle_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Consumer<DeliveryProvider>(
      builder: (_, dp, _) {
        final newCount = dp.newOrders.length;
        final onWayCount = dp.preparingOrders.length + dp.onWayOrders.length;

        return Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              _tab('Yangi', newCount, Colors.blue),
              _tab("Yo'lda", onWayCount, Colors.orange),
              _tab('Yetkazildi', null, const Color(0xFF10B981)),
            ],
          ),
        );
      },
    );
  }

  Tab _tab(String label, int? count, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Courier Panel ─────────────────────────────────────────────────────────────

class _CourierPanel extends StatelessWidget {
  final void Function(Courier) onCourierTap;

  const _CourierPanel({required this.onCourierTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 300,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Text(
                  'Kurierlar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showCourierDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    "Qo'shish",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.12)),

          // List
          Expanded(
            child: Consumer<DeliveryProvider>(
              builder: (_, dp, _) {
                if (dp.couriers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delivery_dining_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Kurierlar yo'q",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: dp.couriers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CourierCard(
                    courier: dp.couriers[i],
                    activeOrderCount: dp.getCourierActiveCount(
                      dp.couriers[i].id!,
                    ),
                    onEdit: () =>
                        _showCourierDialog(context, courier: dp.couriers[i]),
                    onToggle: () => dp.toggleCourierStatus(
                      dp.couriers[i].id!,
                      !dp.couriers[i].isActive,
                    ),
                    onDelete: () => _confirmDelete(context, dp.couriers[i], dp),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCourierDialog(BuildContext context, {Courier? courier}) {
    final isEdit = courier != null;
    final nameCtrl = TextEditingController(text: courier?.name ?? '');
    final phoneCtrl = TextEditingController(text: courier?.phone ?? '');
    bool isActive = courier?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            isEdit ? 'Kurierni tahrirlash' : 'Yangi kuryer',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ism *',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    prefixIcon: Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Holati:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    _StatusToggle(
                      value: isActive,
                      onChange: (v) => setD(() => isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final dp = context.read<DeliveryProvider>();
                if (isEdit) {
                  await dp.updateCourier(
                    courier.copyWith(
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                      isActive: isActive,
                    ),
                  );
                } else {
                  await dp.addCourier(
                    name,
                    phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isEdit ? 'Saqlash' : "Qo'shish",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Courier courier,
    DeliveryProvider dp,
  ) {
    final activeCount = dp.getCourierActiveCount(courier.id!);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "O'chirish",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: activeCount > 0
            ? Text(
                "${courier.name} hozir $activeCount ta yo'ldagi buyurtmaga biriktirilgan. "
                'Avval bu buyurtmalarni yakunlang.',
              )
            : Text("${courier.name} ni o'chirishni tasdiqlaysizmi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          if (activeCount == 0)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await dp.deleteCourier(courier.id!);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                "O'chirish",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Courier Card ──────────────────────────────────────────────────────────────

class _CourierCard extends StatelessWidget {
  final Courier courier;
  final int activeOrderCount;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CourierCard({
    required this.courier,
    required this.activeOrderCount,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = courier.isActive;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeOrderCount > 0
              ? Colors.orange.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delivery_dining_rounded,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF6366F1)
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            courier.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isActive
                                  ? theme.colorScheme.onSurface
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        // Status dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    if (courier.phone?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: courier.phone!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${courier.phone} nusxalandi'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              courier.phone!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (activeOrderCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delivery_dining_rounded,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Hozir: $activeOrderCount ta buyurtma yo'lda",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              Switch.adaptive(
                value: isActive,
                onChanged: (_) => onToggle(),
                activeThumbColor: const Color(0xFF10B981),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Tahrirlash',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: activeOrderCount > 0
                      ? Colors.grey.shade300
                      : Colors.red,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: "O'chirish",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status Toggle ─────────────────────────────────────────────────────────────

class _StatusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChange;

  const _StatusToggle({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChange(true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFF10B981)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Faol',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onChange(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: !value
                  ? Colors.grey.shade600
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Nofaol',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: !value ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Delivery Tab ──────────────────────────────────────────────────────────────

class _DeliveryTab extends StatelessWidget {
  final Set<int> statusFilter;
  final String emptyText;
  final IconData emptyIcon;

  const _DeliveryTab({
    super.key,
    required this.statusFilter,
    required this.emptyText,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DeliveryProvider>(
      builder: (_, dp, _) {
        if (dp.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = dp.orders
            .where((o) => statusFilter.contains(o.deliveryStatus))
            .toList();

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  emptyIcon,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 12),
                Text(
                  emptyText,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _OrderCard(
            order: orders[i],
            couriers: dp.activeCouriers,
            allCouriers: dp.couriers,
          ),
        );
      },
    );
  }
}

// ── Order Card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final List<Courier> couriers;
  final List<Courier> allCouriers;

  const _OrderCard({
    required this.order,
    required this.couriers,
    required this.allCouriers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = order.deliveryStatus == 0;
    final isOnWay = order.deliveryStatus == 1 || order.deliveryStatus == 2;
    final isDone = order.deliveryStatus >= 3;

    // Courier info
    final courierName = order.courierId != null
        ? allCouriers
              .where((c) => c.id == order.courierId)
              .map((c) => c.name)
              .firstOrNull
        : null;

    // Time label
    final dt = order.createdAt;
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNew
              ? Colors.blue.withValues(alpha: 0.2)
              : isOnWay
              ? Colors.orange.withValues(alpha: 0.2)
              : const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isNew
                        ? Colors.blue.withValues(alpha: 0.1)
                        : isOnWay
                        ? Colors.orange.withValues(alpha: 0.1)
                        : const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${order.dailyNumber ?? order.id.substring(0, 6)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isNew
                          ? Colors.blue
                          : isOnWay
                          ? Colors.orange
                          : const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.customerName ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (order.customerPhone?.isNotEmpty == true)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: order.customerPhone!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${order.customerPhone} nusxalandi'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.customerPhone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Address
            if (order.deliveryAddress?.isNotEmpty == true)
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress!,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 6),

            // Price + time row
            Row(
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  '${PriceFormatter.format(order.grandTotal)} so\'m',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (order.deliveryFee > 0) ...[
                  Text(
                    ' + ${PriceFormatter.format(order.deliveryFee)} yo\'l haqi',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 3),
                Text(
                  isDone ? '$timeStr da yetkazildi' : '$timeStr da keldi',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),

            // Courier info (on-way and done)
            if (courierName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.delivery_dining_rounded,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Kuryer: $courierName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],

            // Action buttons
            if (isNew || isOnWay) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (isNew)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAssignDialog(context, order),
                        icon: const Icon(
                          Icons.delivery_dining_rounded,
                          size: 16,
                        ),
                        label: const Text('Kuryer biriktir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  if (isOnWay) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAssignDialog(context, order),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text("Kuryer o'zgartir"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _markDelivered(context, order),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Yetkazildi ✓'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, Order order) {
    if (couriers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Faol kurierlar yo'q")));
      return;
    }

    int? selectedId = order.courierId ?? couriers.first.id;
    final dp = context.read<DeliveryProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
            'Buyurtma #${order.dailyNumber ?? order.id.substring(0, 6)} uchun kuryer',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 360,
            // Flutter 3.32+ da RadioListTile'ning `groupValue`/`onChanged`
            // parametrlari eskirgan — tanlov endi RadioGroup ajdodi orqali
            // boshqariladi.
            child: RadioGroup<int>(
              groupValue: selectedId,
              onChanged: (v) => setD(() => selectedId = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Active couriers
                  ...couriers.map((c) {
                    final count = dp.getCourierActiveCount(c.id!);
                    return RadioListTile<int>(
                      value: c.id!,
                      title: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: count > 0
                          ? Text(
                              'Hozir $count ta buyurtma',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            )
                          : const Text(
                              'Bo\'sh',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF10B981),
                              ),
                            ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),

                  // Inactive couriers (greyed)
                  ...allCouriers
                      .where((c) => !c.isActive)
                      .map(
                        (c) => Opacity(
                          opacity: 0.4,
                          child: RadioListTile<int>(
                            value: c.id!,
                            enabled: false,
                            title: Text(c.name),
                            subtitle: const Text(
                              'Nofaol',
                              style: TextStyle(fontSize: 12),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await dp.assignCourier(
                        orderId: order.id,
                        courierId: selectedId!,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Biriktirish',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markDelivered(BuildContext context, Order order) {
    if (order.courierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval kuryer biriktiring'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    context.read<DeliveryProvider>().markDelivered(order.id);
  }
}

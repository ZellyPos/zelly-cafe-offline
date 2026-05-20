import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/order.dart';
import '../../providers/delivery_provider.dart';
import 'new_delivery_screen.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Yetkazib berish',
          style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          Consumer<DeliveryProvider>(
            builder: (_, p, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF64748B)),
              tooltip: 'Yangilash',
              onPressed: p.loadOrders,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _openNewDelivery,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Yangi buyurtma'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _buildFilterBar(),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorColor: AppTheme.primaryColor,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Barchasi'),
                  Tab(text: 'Yangi'),
                  Tab(text: "Yo'lda"),
                  Tab(text: 'Yetkazildi'),
                  Tab(text: 'Kuryer statistika'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (_, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _OrderList(orders: provider.orders),
              _OrderList(orders: provider.newOrders),
              _OrderList(orders: provider.onWayOrders),
              _OrderList(orders: provider.deliveredOrders),
              _CourierStatsTab(dateRange: _dateRange),
            ],
          );
        },
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Consumer<DeliveryProvider>(
      builder: (_, dp, _) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            // Date range
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      _dateRange.start == _dateRange.end
                          ? DateFormat('dd.MM.yyyy').format(_dateRange.start)
                          : '${DateFormat('dd.MM').format(_dateRange.start)} – ${DateFormat('dd.MM').format(_dateRange.end)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Quick date chips
            _dateChip('Bugun', () => _setDateToday()),
            const SizedBox(width: 6),
            _dateChip('Bu hafta', () => _setDateWeek()),

            const SizedBox(width: 12),
            const VerticalDivider(width: 1, indent: 4, endIndent: 4),
            const SizedBox(width: 12),

            // Courier filter
            DropdownButton<int?>(
              value: dp.filterCourierId,
              underline: const SizedBox(),
              hint: const Text('Barcha kuryerlar',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              isDense: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Barcha kuryerlar',
                      style: TextStyle(fontSize: 12)),
                ),
                ...dp.couriers.map((c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name,
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],
              onChanged: dp.setCourierFilter,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
      ),
    );
  }

  void _setDateToday() {
    final now = DateTime.now();
    setState(() => _dateRange = DateTimeRange(start: now, end: now));
    context.read<DeliveryProvider>().setDateFilter(now, now);
  }

  void _setDateWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    setState(() => _dateRange = DateTimeRange(start: start, end: now));
    context.read<DeliveryProvider>().setDateFilter(start, now);
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      if (!mounted) return;
      context.read<DeliveryProvider>().setDateFilter(picked.start, picked.end);
    }
  }

  Future<void> _openNewDelivery() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NewDeliveryScreen()));
    if (mounted) context.read<DeliveryProvider>().loadOrders();
  }
}

// ── Order list ────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Buyurtma yo\'q',
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => _DeliveryCard(order: orders[i]),
    );
  }
}

// ── Delivery card ─────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final Order order;
  const _DeliveryCard({required this.order});

  static const _statusLabels = [
    'Yangi', 'Tayyorlanmoqda', "Yo'lda", 'Yetkazildi', 'Bekor',
  ];
  static const _statusColors = [
    Color(0xFF6366F1), Color(0xFFF59E0B), Color(0xFF3B82F6),
    Color(0xFF22C55E), Color(0xFFEF4444),
  ];
  static const _nextLabels = ['Tayyorlanmoqda', "Yo'lda", 'Yetkazildi'];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DeliveryProvider>();
    final ds = order.deliveryStatus.clamp(0, 4);
    final isPaid = order.status == 1;
    final statusColor = _statusColors[ds];
    final statusLabel = _statusLabels[ds];

    final itemSummary = order.items.isEmpty
        ? ''
        : order.items
                .take(3)
                .map((i) =>
                    '${i.productName} ×${i.qty.toStringAsFixed(i.qty == i.qty.floorToDouble() ? 0 : 1)}')
                .join(', ') +
            (order.items.length > 3 ? '…' : '');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge(statusLabel, statusColor),
                const SizedBox(width: 8),
                Text(
                  '#${order.dailyNumber ?? order.id.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM HH:mm').format(order.createdAt),
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.person_rounded, order.customerName ?? '-',
                bold: true),
            if (order.customerPhone?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _infoRow(Icons.phone_rounded, order.customerPhone!),
              ),
            const SizedBox(height: 4),
            _infoRow(Icons.location_on_rounded,
                order.deliveryAddress ?? '-'),
            if (order.deliveryNote?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _infoRow(Icons.notes_rounded, order.deliveryNote!,
                    color: const Color(0xFFF59E0B)),
              ),
            if (itemSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(itemSummary,
                  style: const TextStyle(
                      color: Color(0xFF475569), fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(PriceFormatter.format(order.grandTotal),
                        style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (order.deliveryFee > 0)
                      Text(
                          'Yetkazish: +${PriceFormatter.format(order.deliveryFee)}',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
                const Spacer(),
                if (!isPaid && ds < 3) ...[
                  OutlinedButton(
                    onPressed: () =>
                        provider.updateDeliveryStatus(order.id, ds + 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: statusColor,
                      side: BorderSide(color: statusColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Text(_nextLabels[ds],
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isPaid && ds >= 1)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showCheckoutDialog(context, order),
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text("To'lash"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                if (!isPaid)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined,
                        color: Color(0xFFEF4444)),
                    tooltip: 'Bekor qilish',
                    onPressed: () =>
                        _confirmCancel(context, order, provider),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      );

  Widget _infoRow(IconData icon, String text,
      {bool bold = false, Color? color}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color ?? const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.w600 : FontWeight.normal,
                    color: color ?? const Color(0xFF475569))),
          ),
        ],
      );

  void _showCheckoutDialog(BuildContext context, Order order) {
    final paymentTypes = ['Naqd', 'Karta', 'Nasiya'];
    String selectedPayment = paymentTypes.first;
    final amountCtrl = TextEditingController(
        text: order.grandTotal.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text("To'lov"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: paymentTypes
                    .map((t) => ChoiceChip(
                          label: Text(t),
                          selected: selectedPayment == t,
                          selectedColor: AppTheme.primaryColor
                              .withValues(alpha: 0.15),
                          onSelected: (_) =>
                              setS(() => selectedPayment = t),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qabul qilingan summa',
                  suffixText: "so'm",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: amountCtrl,
                builder: (_, v, _) {
                  final paid = double.tryParse(v.text) ?? 0;
                  final ch = paid - order.grandTotal;
                  if (ch > 0) {
                    return Text(
                        'Qaytim: ${PriceFormatter.format(ch)}',
                        style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Bekor')),
            ElevatedButton(
              onPressed: () async {
                final paid = double.tryParse(amountCtrl.text) ??
                    order.grandTotal;
                Navigator.pop(ctx);
                final err = await context
                    .read<DeliveryProvider>()
                    .checkoutOrder(order.id, selectedPayment, paid);
                if (!context.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(err),
                      backgroundColor: Colors.red));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("To'lov amalga oshirildi"),
                        backgroundColor: Color(0xFF22C55E)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white),
              child: const Text('Tasdiqlash'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(
      BuildContext context, Order order, DeliveryProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bekor qilish'),
        content: const Text('Bu buyurtmani bekor qilmoqchimisiz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Yo'q")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.updateDeliveryStatus(order.id, 4);
            },
            child: const Text('Ha, bekor qilish',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Courier stats tab ─────────────────────────────────────────────────────────

class _CourierStatsTab extends StatefulWidget {
  final DateTimeRange dateRange;
  const _CourierStatsTab({required this.dateRange});

  @override
  State<_CourierStatsTab> createState() => _CourierStatsTabState();
}

class _CourierStatsTabState extends State<_CourierStatsTab> {
  List<Map<String, dynamic>> _stats = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CourierStatsTab old) {
    super.didUpdateWidget(old);
    if (old.dateRange != widget.dateRange) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await context.read<DeliveryProvider>().getCourierStats(
          start: widget.dateRange.start,
          end: widget.dateRange.end,
        );
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Kuryer statistikasi yo\'q',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stats.length,
      itemBuilder: (_, i) {
        final s = _stats[i];
        final deliveries = (s['deliveries'] as num?)?.toInt() ?? 0;
        final revenue = (s['revenue'] as num?)?.toDouble() ?? 0;
        final fees = (s['delivery_fees'] as num?)?.toDouble() ?? 0;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: const Icon(Icons.delivery_dining_rounded,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] as String? ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B))),
                      if ((s['phone'] as String?)?.isNotEmpty == true)
                        Text(s['phone'] as String,
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statChip(
                        '$deliveries ta buyurtma', const Color(0xFF6366F1)),
                    const SizedBox(height: 4),
                    Text(PriceFormatter.format(revenue),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22C55E))),
                    if (fees > 0)
                      Text('Yetkazish: ${PriceFormatter.format(fees)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}

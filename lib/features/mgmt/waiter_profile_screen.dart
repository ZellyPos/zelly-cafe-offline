import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/waiter.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../providers/waiter_provider.dart';
import '../../core/printing_service.dart';
import '../reports/widgets/order_details_dialog.dart';

class WaiterProfileScreen extends StatefulWidget {
  final Waiter waiter;

  const WaiterProfileScreen({super.key, required this.waiter});

  @override
  State<WaiterProfileScreen> createState() => _WaiterProfileScreenState();
}

class _WaiterProfileScreenState extends State<WaiterProfileScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now().add(const Duration(days: 1)),
  );

  bool _isLoading = false;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = {
    'order_count': 0,
    'total_sales': 0.0,
    'earned': 0.0,
    'paid': 0.0,
    'payable': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<WaiterProvider>();
      final data = await provider.getWaiterProfileData(
        widget.waiter.id!,
        _dateRange.start,
        _dateRange.end,
      );
      if (mounted) {
        setState(() {
          _summary = data['summary'] ?? _summary;
          _orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
          _payments = List<Map<String, dynamic>>.from(data['payments'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.waiter.name,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.grey.shade800),
        actions: [
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              "${DateFormat('dd.MM.yyyy').format(_dateRange.start)} - ${DateFormat('dd.MM.yyyy').format(_dateRange.end)}",
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildTabs(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderInfo() {
    final bool isKassa = widget.waiter.name == "Kassa";
    final String typeLabel = isKassa
        ? "Kassa"
        : (widget.waiter.type == 0 ? "Fiksal" : "Foizli");
    final Color typeColor = isKassa
        ? Colors.teal
        : (widget.waiter.type == 0 ? Colors.indigo : Colors.orange);
    final String valueText = isKassa
        ? "Asosiy xodim"
        : (widget.waiter.type == 0
              ? "${PriceFormatter.format(widget.waiter.value)} / buyurtma"
              : "${widget.waiter.value}% savdodan");

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            typeLabel,
            style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          valueText,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildCard("Buyurtmalar", "${_summary['order_count']}", Colors.blue),
        _buildCard(
          "Jami savdo",
          PriceFormatter.format((_summary['total_sales'] as num).toDouble()),
          Colors.green,
        ),
        _buildCard(
          "Hisoblangan",
          PriceFormatter.format((_summary['earned'] as num).toDouble()),
          Colors.indigo,
        ),
        _buildCard(
          "To'langan",
          PriceFormatter.format((_summary['paid'] as num).toDouble()),
          Colors.red,
        ),
        if ((_summary['payable'] as num).toDouble() >= 0)
          _buildCard(
            "Hozir olishi kerak",
            PriceFormatter.format((_summary['payable'] as num).toDouble()),
            Colors.orange,
            isHighlight: true,
          )
        else
          _buildCard(
            "Qarz (Minus balans)",
            PriceFormatter.format(
              (_summary['payable'] as num).toDouble().abs(),
            ),
            Colors.red.shade700,
            isHighlight: true,
            icon: Icons.warning_amber_rounded,
          ),
      ],
    );
  }

  Widget _buildCard(
    String title,
    String value,
    Color color, {
    bool isHighlight = false,
    IconData? icon,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlight ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isHighlight)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isHighlight
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (icon != null) Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.white : const Color(0xFF1E293B),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const TabBar(
              labelColor: Color(0xFF4C1D95),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF4C1D95),
              tabs: [
                Tab(text: "Buyurtmalar"),
                Tab(text: "Oylik to'lovlari"),
              ],
            ),
          ),
          SizedBox(
            height: 600,
            child: TabBarView(
              children: [_buildOrdersList(), _buildPaymentsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_orders.isEmpty) return _buildEmptyState("Buyurtmalar mavjud emas");
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final order = _orders[index];
        final isDineIn = order['order_type'] == 0;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isDineIn
                ? Colors.blue.shade50
                : Colors.green.shade50,
            child: Icon(
              isDineIn ? Icons.restaurant : Icons.shopping_bag,
              size: 20,
              color: isDineIn ? Colors.blue : Colors.green,
            ),
          ),
          title: Text(
            "#${order['id'].toString().substring(0, 8).toUpperCase()}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            DateFormat(
              'dd.MM.yyyy HH:mm',
            ).format(DateTime.parse(order['created_at'])),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => OrderDetailsDialog(orderId: order['id']),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.waiter.name != "Kassa")
                ElevatedButton.icon(
                  onPressed: _showPaymentModal,
                  icon: const Icon(Icons.add),
                  label: const Text("Oylik berish"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C1D95),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _payments.isEmpty
              ? _buildEmptyState("To'lovlar tariyxda yo'q")
              : ListView.separated(
                  itemCount: _payments.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final p = _payments[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF1F5F9),
                        child: Icon(
                          Icons.payments_outlined,
                          color: Colors.indigo,
                        ),
                      ),
                      title: Text(
                        PriceFormatter.formatWithCurrency(
                          (p['amount'] as num).toDouble(),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        DateFormat(
                          'dd.MM.yyyy HH:mm',
                        ).format(DateTime.parse(p['paid_at'])),
                      ),
                      trailing:
                          p['note'] != null && p['note'].toString().isNotEmpty
                          ? Text(p['note'].toString())
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showPaymentModal() {
    final amountController = TextEditingController(
      text: (_summary['payable'] as num).toInt().toString(),
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Oylik to'lash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "To'lov summasi",
                suffixText: "so'm",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Izoh (ixtiyoriy)"),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: amountController,
              builder: (context, value, _) {
                final amount = int.tryParse(value.text) ?? 0;
                final currentPayable = (_summary['payable'] as num).toDouble();
                if (amount > currentPayable && currentPayable >= 0) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Diqqat: bu to‘lov qarz (minus balans) hosil qiladi.",
                            style: TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Bekor qilish",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;

              await context.read<WaiterProvider>().addSalaryPayment(
                widget.waiter.id!,
                amount,
                noteController.text,
              );

              // Print receipt
              await PrintingService.printWaiterSalaryPayout(
                waiterName: widget.waiter.name,
                amount: amount.toDouble(),
                dateRange:
                    "${DateFormat('dd.MM.yyyy').format(_dateRange.start)} - ${DateFormat('dd.MM.yyyy').format(_dateRange.end)}",
                earned: (_summary['earned'] as num).toDouble(),
                paidBefore: (_summary['paid'] as num).toDouble(),
                payableAfter: (_summary['payable'] as num).toDouble() - amount,
                note: noteController.text,
              );

              if (context.mounted) {
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "To'lov muvaffaqiyatli saqlandi va chek chiqarildi",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("To'lash"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(msg, style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
